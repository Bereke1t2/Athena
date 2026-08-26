package database

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"athena/backend/internal/domain/research"
)

// isUniqueViolation reports whether err is a Postgres 23505 constraint
// violation (used to detect concurrent-insert races).
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

// PaperStore implements research.PaperWriter and research.PaperReader on
// PostgreSQL. Every UpsertPaper runs in one transaction and is idempotent:
// replaying an equivalent record updates provenance but never duplicates rows.
type PaperStore struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

func NewPaperStore(pool *pgxpool.Pool, logger *slog.Logger) *PaperStore {
	if logger == nil {
		logger = slog.Default()
	}
	return &PaperStore{pool: pool, logger: logger}
}

const coreCols = `id, title, abstract, publication_date, publication_year, venue_name,
	venue_type, publication_type::text, language, doi::text, arxiv_id,
	oa_status::text, best_oa_url, license, cited_by_count, reference_count`

type storedCore struct {
	id         uuid.UUID
	title      string
	abstract   *string
	pubDate    *time.Time
	year       int
	venueName  string
	venueType  string
	pubType    research.PublicationType
	language   string
	doi        string
	arxivID    string
	oaStatus   research.OAStatus
	bestOAURL  string
	license    string
	citedBy    int
	references int
}

func scanCore(row pgx.Row) (storedCore, error) {
	var c storedCore
	var pubType, oaStatus string
	err := row.Scan(&c.id, &c.title, &c.abstract, &c.pubDate, &c.year, &c.venueName,
		&c.venueType, &pubType, &c.language, &c.doi, &c.arxivID,
		&oaStatus, &c.bestOAURL, &c.license, &c.citedBy, &c.references)
	if err != nil {
		return c, err
	}
	c.pubType = research.PublicationType(pubType)
	c.oaStatus = research.OAStatus(oaStatus)
	return c, nil
}

// UpsertPaper persists one normalized paper with full identity resolution.
func (s *PaperStore) UpsertPaper(ctx context.Context, p research.Paper) (research.UpsertResult, error) {
	if p.Title == "" || p.TitleNormalized == "" || p.Fingerprint == "" ||
		p.Provenance.ProviderSlug == "" || p.Provenance.NativeID == "" {
		return research.UpsertResult{}, fmt.Errorf("%w: paper requires title, identity and provenance",
			research.ErrInvalidInput)
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return research.UpsertResult{}, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	match, err := s.findIdentityMatch(ctx, tx, p)
	if err != nil {
		return research.UpsertResult{}, err
	}
	target, decision := research.ResolveTarget(p, match)

	s.logger.Debug("identity resolution",
		"decision", decision.String(),
		"title_normalized", p.TitleNormalized,
		"provider", p.Provenance.ProviderSlug)

	var res research.UpsertResult
	switch decision {
	case research.ConflictKeepBoth:
		return research.UpsertResult{}, research.ErrIdentityConflict
	case research.CreateNew:
		res, err = s.insertNew(ctx, tx, p)
		if isUniqueViolation(err) {
			// Concurrent chains racing to insert the same paper (overlapping
			// windows): the winner committed after our SELECT. Re-resolve and
			// merge instead of failing.
			s.logger.Debug("insert raced with concurrent writer; merging",
				"provider", p.Provenance.ProviderSlug,
				"native_id", p.Provenance.NativeID)
			match, err2 := s.findIdentityMatch(ctx, tx, p)
			if err2 != nil {
				return research.UpsertResult{}, err2
			}
			target, decision = research.ResolveTarget(p, match)
			if target == uuid.Nil || decision == research.CreateNew ||
				decision == research.ConflictKeepBoth {
				return research.UpsertResult{},
					fmt.Errorf("post-conflict re-resolve found no mergeable target: %w", err)
			}
			res, err = s.mergeInto(ctx, tx, target, p)
		}
	default:
		res, err = s.mergeInto(ctx, tx, target, p)
	}
	if err != nil {
		return research.UpsertResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return research.UpsertResult{}, fmt.Errorf("commit: %w", err)
	}
	return res, nil
}

func (s *PaperStore) findIdentityMatch(ctx context.Context, tx pgx.Tx, p research.Paper) (research.IdentityMatch, error) {
	m := research.IdentityMatch{}

	types := make([]string, 0, len(p.Identifiers))
	values := make([]string, 0, len(p.Identifiers))
	for _, id := range p.Identifiers {
		types = append(types, string(id.Type))
		values = append(values, id.Value)
	}

	if len(types) > 0 {
		rows, err := tx.Query(ctx, `
			SELECT DISTINCT paper_id FROM paper_identifiers
			WHERE (id_type, id_value) IN (
				SELECT t AS id_type, v AS id_value FROM unnest($1::text[], $2::text[]) AS ref(t, v)
			)`, types, values)
		if err != nil {
			return m, fmt.Errorf("identifier lookup: %w", err)
		}
		for rows.Next() {
			var id uuid.UUID
			if err := rows.Scan(&id); err != nil {
				rows.Close()
				return m, err
			}
			m.MatchedIDs = append(m.MatchedIDs, id)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return m, err
		}
	}

	if len(m.MatchedIDs) == 0 && p.Fingerprint != "" {
		row := tx.QueryRow(ctx, `
			SELECT id, COALESCE(doi::text,''), COALESCE(arxiv_id,'')
			FROM papers WHERE fingerprint = $1 AND deleted_at IS NULL
			ORDER BY created_at LIMIT 1`, p.Fingerprint)
		var id uuid.UUID
		var doi, arxiv string
		err := row.Scan(&id, &doi, &arxiv)
		switch {
		case errors.Is(err, pgx.ErrNoRows):
		case err != nil:
			return m, fmt.Errorf("fingerprint lookup: %w", err)
		default:
			m.FingerprintCandidate = &id
			m.CandidateDOI = doi
			m.CandidateArxivID = arxiv
		}
	}
	return m, nil
}

// contentFingerprint returns the provenance fingerprint for an incoming
// payload. Adapters should set Provenance.PayloadFingerprint over their raw
// payload; this fallback hashes the canonical fields so that idempotency
// still holds when they don't.
func contentFingerprint(p research.Paper) string {
	if p.Provenance.PayloadFingerprint != "" {
		return p.Provenance.PayloadFingerprint
	}
	h := sha256.New()
	for _, s := range []string{
		p.TitleNormalized, p.Abstract,
		strconv.Itoa(p.Year), strconv.Itoa(p.CitedByCount), strconv.Itoa(p.ReferenceCount),
	} {
		h.Write([]byte(s))
		h.Write([]byte{0x1f})
	}
	return hex.EncodeToString(h.Sum(nil))
}

func (s *PaperStore) sourceIDBySlug(ctx context.Context, tx pgx.Tx, slug string) (uuid.UUID, error) {
	var id uuid.UUID
	err := tx.QueryRow(ctx, `SELECT id FROM sources WHERE slug = $1`, slug).Scan(&id)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return uuid.Nil, fmt.Errorf("%w: unknown source %q", research.ErrInvalidInput, slug)
	case err != nil:
		return uuid.Nil, fmt.Errorf("source lookup: %w", err)
	}
	return id, nil
}

const insertPaperCols = `id, title, title_normalized, fingerprint, abstract,
	publication_date, publication_year, venue_name, venue_type, publication_type,
	language, doi, arxiv_id, oa_status, is_open_access, best_oa_url, license,
	cited_by_count, reference_count`

func (s *PaperStore) insertNew(ctx context.Context, tx pgx.Tx, p research.Paper) (research.UpsertResult, error) {
	id := uuid.New()
	if p.Provenance.FetchedAt.IsZero() {
		p.Provenance.FetchedAt = time.Now().UTC()
	}

	tag, err := tx.Exec(ctx, `
		INSERT INTO papers (`+insertPaperCols+`)
		VALUES ($1,$2,$3,$4,NULLIF($5,''),$6,$7,NULLIF($8,''),NULLIF($9,''),$10::publication_type,
			NULLIF($11,''),NULLIF($12,''),NULLIF($13,''),$14::oa_status,$15,NULLIF($16,''),
			NULLIF($17,''),$18,$19)`,
		id, p.Title, p.TitleNormalized, p.Fingerprint, p.Abstract,
		p.PublishedOn, int16(p.Year), p.VenueName, p.VenueType, string(p.PubType),
		p.Language, p.DOI(), p.ArxivID(), string(p.OA.Status), p.OA.IsOpen(),
		p.OA.URL, p.OA.License, p.CitedByCount, p.ReferenceCount)
	if err != nil {
		return research.UpsertResult{}, fmt.Errorf("insert paper: %w", err)
	}
	if tag.RowsAffected() != 1 {
		return research.UpsertResult{}, fmt.Errorf("insert paper: no rows affected")
	}

	if err := s.upsertIdentifiers(ctx, tx, id, p.Identifiers); err != nil {
		return research.UpsertResult{}, err
	}
	if err := s.upsertAuthors(ctx, tx, id, p.Authors); err != nil {
		return research.UpsertResult{}, err
	}
	if err := s.upsertTopics(ctx, tx, id, p.Topics); err != nil {
		return research.UpsertResult{}, err
	}
	if err := s.upsertVersions(ctx, tx, id, p.Versions); err != nil {
		return research.UpsertResult{}, err
	}
	srcID, err := s.sourceIDBySlug(ctx, tx, p.Provenance.ProviderSlug)
	if err != nil {
		return research.UpsertResult{}, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO paper_sources (id, paper_id, source_id, native_id, content_fingerprint, first_seen_at, last_seen_at)
		VALUES ($1,$2,$3,$4,$5,$6,$6)
		ON CONFLICT (source_id, native_id) DO NOTHING`,
		uuid.New(), id, srcID, p.Provenance.NativeID, contentFingerprint(p), p.Provenance.FetchedAt); err != nil {
		return research.UpsertResult{}, fmt.Errorf("insert paper source: %w", err)
	}
	return research.UpsertResult{PaperID: id, Created: true, ContentChanged: true}, nil
}

// mergeInto applies an incoming record onto an already-stored paper. Policy is
// conservative: fill blanks, grow counts, never overwrite populated fields.
func (s *PaperStore) mergeInto(ctx context.Context, tx pgx.Tx, target uuid.UUID, p research.Paper) (research.UpsertResult, error) {
	fp := contentFingerprint(p)
	srcID, err := s.sourceIDBySlug(ctx, tx, p.Provenance.ProviderSlug)
	if err != nil {
		return research.UpsertResult{}, err
	}

	var provFP string
	var haveProv bool
	err = tx.QueryRow(ctx, `
		SELECT content_fingerprint FROM paper_sources
		WHERE source_id = $1 AND native_id = $2`, srcID, p.Provenance.NativeID).Scan(&provFP)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
	case err != nil:
		return research.UpsertResult{}, fmt.Errorf("provenance lookup: %w", err)
	default:
		haveProv = true
	}

	seen := haveProv && provFP == fp
	if seen {
		// Byte-identical replay of a payload this source already delivered:
		// touch nothing except the last-seen watermark.
		if _, err := tx.Exec(ctx, `
			UPDATE paper_sources SET last_seen_at = now()
			WHERE source_id = $1 AND native_id = $2`, srcID, p.Provenance.NativeID); err != nil {
			return research.UpsertResult{}, fmt.Errorf("touch provenance: %w", err)
		}
		return research.UpsertResult{PaperID: target, Created: false, ContentChanged: false}, nil
	}

	if p.Provenance.FetchedAt.IsZero() {
		p.Provenance.FetchedAt = time.Now().UTC()
	}
	if _, err := tx.Exec(ctx, `
		UPDATE papers SET
			abstract         = COALESCE(abstract, NULLIF($2,'')),
			publication_date = COALESCE(publication_date, $3),
			publication_year = COALESCE(publication_year, $4),
			venue_name       = COALESCE(NULLIF(venue_name,''), NULLIF($5,'')),
			venue_type       = COALESCE(NULLIF(venue_type,''), NULLIF($6,'')),
			language         = COALESCE(language, NULLIF($7,'')),
			doi              = COALESCE(doi, NULLIF($8,'')),
			arxiv_id         = COALESCE(arxiv_id, NULLIF($9,'')),
			oa_status        = CASE WHEN oa_status = 'unknown' THEN $10::oa_status ELSE oa_status END,
			is_open_access   = is_open_access OR $11,
			best_oa_url      = COALESCE(best_oa_url, NULLIF($12,'')),
			license          = COALESCE(license, NULLIF($13,'')),
			cited_by_count   = GREATEST(cited_by_count, $14),
			reference_count  = GREATEST(reference_count, $15),
			updated_at       = now()
		WHERE id = $1`,
		target, p.Abstract, p.PublishedOn, int16(p.Year), p.VenueName, p.VenueType,
		p.Language, p.DOI(), p.ArxivID(), string(p.OA.Status), p.OA.IsOpen(),
		p.OA.URL, p.OA.License, p.CitedByCount, p.ReferenceCount); err != nil {
		return research.UpsertResult{}, fmt.Errorf("merge paper: %w", err)
	}

	if err := s.upsertIdentifiers(ctx, tx, target, p.Identifiers); err != nil {
		return research.UpsertResult{}, err
	}
	if err := s.upsertAuthors(ctx, tx, target, p.Authors); err != nil {
		return research.UpsertResult{}, err
	}
	if err := s.upsertTopics(ctx, tx, target, p.Topics); err != nil {
		return research.UpsertResult{}, err
	}
	if err := s.upsertVersions(ctx, tx, target, p.Versions); err != nil {
		return research.UpsertResult{}, err
	}
	if haveProv {
		if _, err := tx.Exec(ctx, `
			UPDATE paper_sources
			SET content_fingerprint = $3, last_seen_at = now()
			WHERE source_id = $1 AND native_id = $2`, srcID, p.Provenance.NativeID, fp); err != nil {
			return research.UpsertResult{}, fmt.Errorf("update provenance: %w", err)
		}
	} else {
		if _, err := tx.Exec(ctx, `
			INSERT INTO paper_sources (id, paper_id, source_id, native_id, content_fingerprint, first_seen_at, last_seen_at)
			VALUES ($1,$2,$3,$4,$5,$6,$6)
			ON CONFLICT (source_id, native_id) DO NOTHING`,
			uuid.New(), target, srcID, p.Provenance.NativeID, fp, p.Provenance.FetchedAt); err != nil {
			return research.UpsertResult{}, fmt.Errorf("insert provenance: %w", err)
		}
	}
	return research.UpsertResult{PaperID: target, Created: false, ContentChanged: true}, nil
}

func (s *PaperStore) upsertIdentifiers(ctx context.Context, tx pgx.Tx, paperID uuid.UUID, ids []research.Identifier) error {
	if len(ids) == 0 {
		return nil
	}
	types := make([]string, 0, len(ids))
	values := make([]string, 0, len(ids))
	for _, id := range ids {
		types = append(types, string(id.Type))
		values = append(values, id.Value)
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO paper_identifiers (id_type, id_value, paper_id)
		SELECT t, v, $3 FROM unnest($1::text[], $2::text[]) AS ref(t, v)
		ON CONFLICT (id_type, id_value) DO NOTHING`, types, values, paperID); err != nil {
		return fmt.Errorf("upsert identifiers: %w", err)
	}
	return nil
}

var authorProviderIDTypes = map[research.IdentifierType]bool{
	research.IDTypeSemanticScholar: true,
	research.IDTypeOpenAlex:        true,
}

func (s *PaperStore) upsertAuthors(ctx context.Context, tx pgx.Tx, paperID uuid.UUID, authors []research.AuthorRef) error {
	// Authorship is replaced wholesale: provider data can reorder positions or
	// duplicate entries across deliveries, which would otherwise collide with
	// the (paper_id, author_id) and (paper_id, position) unique constraints.
	if _, err := tx.Exec(ctx, `DELETE FROM paper_authors WHERE paper_id = $1`, paperID); err != nil {
		return fmt.Errorf("clear paper authors: %w", err)
	}
	seenAuthors := make(map[uuid.UUID]bool, len(authors))
	for _, a := range authors {
		if strings.TrimSpace(a.DisplayName) == "" {
			continue
		}
		norm := research.NormalizePersonName(a.DisplayName)

		var authorID uuid.UUID
		switch {
		case a.ORCID != "":
			err := tx.QueryRow(ctx, `SELECT id FROM authors WHERE orcid = $1`, a.ORCID).Scan(&authorID)
			switch {
			case errors.Is(err, pgx.ErrNoRows):
				authorID = s.createAuthor(ctx, tx, a, norm)
			case err != nil:
				return fmt.Errorf("author orcid lookup: %w", err)
			}
		default:
			err := tx.QueryRow(ctx, `
				SELECT id FROM authors WHERE name_normalized = $1 ORDER BY created_at LIMIT 1`,
				norm).Scan(&authorID)
			switch {
			case errors.Is(err, pgx.ErrNoRows):
				authorID = s.createAuthor(ctx, tx, a, norm)
			case err != nil:
				return fmt.Errorf("author name lookup: %w", err)
			}
		}
		if authorID == uuid.Nil {
			continue
		}
		if seenAuthors[authorID] {
			continue
		}
		seenAuthors[authorID] = true

		for t, v := range a.ProviderIDs {
			if !authorProviderIDTypes[t] || v == "" {
				continue
			}
			if _, err := tx.Exec(ctx, `
				INSERT INTO author_identifiers (id_type, id_value, author_id)
				VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
				string(t), v, authorID); err != nil {
				return fmt.Errorf("upsert author identifier: %w", err)
			}
		}

		// affiliation is NOT NULL text[]; a nil Go slice would encode as NULL.
		affil := a.Affiliation
		if affil == nil {
			affil = []string{}
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO paper_authors (paper_id, author_id, raw_name, position, affiliation)
			VALUES ($1,$2,$3,$4,$5)
			ON CONFLICT (paper_id, position) DO UPDATE
			SET author_id = EXCLUDED.author_id, raw_name = EXCLUDED.raw_name,
			    affiliation = EXCLUDED.affiliation`,
			paperID, authorID, a.DisplayName, a.Position, affil); err != nil {
			return fmt.Errorf("upsert paper author: %w", err)
		}
	}
	return nil
}

func (s *PaperStore) createAuthor(ctx context.Context, tx pgx.Tx, a research.AuthorRef, norm string) uuid.UUID {
	id := uuid.New()
	if _, err := tx.Exec(ctx, `
		INSERT INTO authors (id, display_name, name_normalized, orcid)
		VALUES ($1,$2,$3,NULLIF($4,'')) ON CONFLICT DO NOTHING`,
		id, strings.TrimSpace(a.DisplayName), norm, a.ORCID); err != nil {
		s.logger.Warn("create author failed", "error", err, "name", a.DisplayName)
		return uuid.Nil
	}
	return id
}

func slugifyTopic(name string) string {
	lowered := research.NormalizeTitle(name)
	fields := strings.Fields(lowered)
	if len(fields) == 0 {
		return ""
	}
	out := strings.Join(fields, "-")
	if len(out) > 80 {
		out = out[:80]
	}
	return out
}

func (s *PaperStore) upsertTopics(ctx context.Context, tx pgx.Tx, paperID uuid.UUID, topics []research.TopicRef) error {
	for i, t := range topics {
		name := strings.TrimSpace(t.Name)
		if name == "" {
			continue
		}
		slug := t.Slug
		if slug == "" {
			slug = slugifyTopic(name)
		}
		if slug == "" {
			continue
		}
		isPrimary := t.IsPrimary || i == 0

		var topicID uuid.UUID
		err := tx.QueryRow(ctx, `SELECT id FROM topics WHERE slug = $1 LIMIT 1`, slug).Scan(&topicID)
		switch {
		case errors.Is(err, pgx.ErrNoRows):
			topicID = uuid.New()
			if _, err := tx.Exec(ctx, `
				INSERT INTO topics (id, slug, name, kind, provider_key)
				VALUES ($1,$2,$3,'topic',NULLIF($4,''))
				ON CONFLICT (slug) DO NOTHING`, topicID, slug, name, t.ProviderKey); err != nil {
				return fmt.Errorf("create topic: %w", err)
			}
		case err != nil:
			return fmt.Errorf("topic lookup: %w", err)
		}

		score := t.Score
		if score < 0 {
			score = 0
		} else if score > 1 {
			score = 1
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO paper_topics (paper_id, topic_id, score, is_primary, assigned_by)
			VALUES ($1,$2,$3,$4,'provider')
			ON CONFLICT (paper_id, topic_id) DO UPDATE
			SET score = EXCLUDED.score,
			    is_primary = paper_topics.is_primary OR EXCLUDED.is_primary`,
			paperID, topicID, score, isPrimary); err != nil {
			return fmt.Errorf("upsert paper topic: %w", err)
		}
	}
	return nil
}

func (s *PaperStore) upsertVersions(ctx context.Context, tx pgx.Tx, paperID uuid.UUID, versions []research.VersionRef) error {
	var primaryVersionID *uuid.UUID
	for _, v := range versions {
		if strings.TrimSpace(v.URL) == "" {
			continue
		}
		kind := string(v.Kind)
		switch kind {
		case "preprint", "publisher":
		default:
			kind = "other"
		}
		var vid uuid.UUID
		err := tx.QueryRow(ctx, `
			INSERT INTO paper_versions (id, paper_id, version_kind, doi, arxiv_id, url, published_on, is_primary)
			VALUES ($1,$2,$3,NULLIF($4,''),NULLIF($5,''),$6,$7,$8)
			ON CONFLICT (paper_id, version_kind, url) DO UPDATE
			SET is_primary = paper_versions.is_primary OR EXCLUDED.is_primary
			RETURNING id`,
			uuid.New(), paperID, kind, v.DOI, v.ArxivID, v.URL, v.PublishedOn, v.IsPrimary).Scan(&vid)
		if err != nil {
			return fmt.Errorf("upsert version: %w", err)
		}
		if v.IsPrimary && primaryVersionID == nil {
			primaryVersionID = &vid
		}
	}
	if primaryVersionID != nil {
		if _, err := tx.Exec(ctx, `
			UPDATE papers SET primary_version_id = $2
			WHERE id = $1 AND primary_version_id IS NULL`, paperID, *primaryVersionID); err != nil {
			return fmt.Errorf("set primary version: %w", err)
		}
	}
	return nil
}

// ResolveCitationEdges links citingPaperID to locally stored references.
// Edges whose targets are not yet ingested are ignored; they get linked when
// the cited paper arrives (replay makes this safe).
func (s *PaperStore) ResolveCitationEdges(ctx context.Context, citingPaperID uuid.UUID, refs []research.Identifier) (int, error) {
	if len(refs) == 0 {
		return 0, nil
	}
	pool := s.pool
	types := make([]string, 0, len(refs))
	values := make([]string, 0, len(refs))
	for _, r := range refs {
		types = append(types, string(r.Type))
		values = append(values, r.Value)
	}
	tag, err := pool.Exec(ctx, `
		WITH refs(id_type, id_value) AS (
			SELECT * FROM unnest($2::text[], $3::text[])
		),
		resolved AS (
			SELECT DISTINCT pi.paper_id
			FROM refs
			JOIN paper_identifiers pi ON pi.id_type = refs.id_type AND pi.id_value = refs.id_value
			WHERE pi.paper_id <> $1
		)
		INSERT INTO citations (citing_paper_id, cited_paper_id)
		SELECT $1, paper_id FROM resolved
		ON CONFLICT DO NOTHING`, citingPaperID, types, values)
	if err != nil {
		return 0, fmt.Errorf("resolve citation edges: %w", err)
	}
	return int(tag.RowsAffected()), nil
}
