package migrations

import (
	"context"
	"fmt"
	"io/fs"
	"log"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
)

type migrationFile struct {
	version  int64
	name     string
	filename string
}

// Apply runs all pending database migrations against the given connection string.
// It is idempotent and safe to run on application boot.
func Apply(ctx context.Context, dbURL string) error {
	if strings.TrimSpace(dbURL) == "" {
		return fmt.Errorf("no database URL configured")
	}

	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database for migrations: %w", err)
	}
	defer conn.Close(ctx)

	// Ensure schema_migrations table exists (compatible with golang-migrate).
	_, err = conn.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version bigint NOT NULL PRIMARY KEY,
			dirty boolean NOT NULL DEFAULT false
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to ensure schema_migrations table: %w", err)
	}

	var currentVersion int64
	var dirty bool
	row := conn.QueryRow(ctx, `SELECT version, dirty FROM schema_migrations LIMIT 1;`)
	if err := row.Scan(&currentVersion, &dirty); err != nil {
		if err != pgx.ErrNoRows {
			return fmt.Errorf("failed to read schema_migrations: %w", err)
		}
		currentVersion = 0
		dirty = false
	}

	if dirty {
		return fmt.Errorf("database schema is in dirty state at version %d; resolve manually before migrating", currentVersion)
	}

	files, err := loadUpMigrations()
	if err != nil {
		return err
	}

	applied := 0
	for _, m := range files {
		if m.version <= currentVersion {
			continue
		}

		log.Printf("Applying migration %s (version %d)...", m.filename, m.version)
		content, err := fs.ReadFile(FS, m.filename)
		if err != nil {
			return fmt.Errorf("failed to read migration %s: %w", m.filename, err)
		}

		if _, err := conn.Exec(ctx, string(content)); err != nil {
			return fmt.Errorf("failed to execute migration %s: %w", m.filename, err)
		}

		// Update schema_migrations table to reflect new version.
		if _, err := conn.Exec(ctx, `DELETE FROM schema_migrations;`); err != nil {
			return fmt.Errorf("failed to clear schema_migrations for %s: %w", m.filename, err)
		}
		if _, err := conn.Exec(ctx, `INSERT INTO schema_migrations (version, dirty) VALUES ($1, false);`, m.version); err != nil {
			return fmt.Errorf("failed to update schema_migrations for %s: %w", m.filename, err)
		}

		log.Printf("Successfully applied %s", m.filename)
		applied++
	}

	if applied == 0 {
		log.Printf("Database schema is up to date (version %d).", currentVersion)
	} else {
		log.Printf("Successfully applied %d migration(s). Current version: %d", applied, files[len(files)-1].version)
	}

	return nil
}

func loadUpMigrations() ([]migrationFile, error) {
	entries, err := fs.ReadDir(FS, ".")
	if err != nil {
		return nil, fmt.Errorf("failed to read migrations dir: %w", err)
	}

	var list []migrationFile
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".up.sql") {
			continue
		}

		name := e.Name()
		parts := strings.SplitN(name, "_", 2)
		if len(parts) < 2 {
			continue
		}

		v, err := strconv.ParseInt(parts[0], 10, 64)
		if err != nil {
			continue
		}

		list = append(list, migrationFile{
			version:  v,
			name:     strings.TrimSuffix(parts[1], ".up.sql"),
			filename: filepath.Base(name),
		})
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].version < list[j].version
	})

	return list, nil
}
