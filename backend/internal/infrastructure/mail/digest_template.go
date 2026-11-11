package mail

import (
	"bytes"
	"fmt"
	"html"
	"html/template"
	"strings"

	domaindigest "athena/backend/internal/domain/digest"
	domainuser "athena/backend/internal/domain/user"
)

// RenderDigestEmail builds responsive HTML and plaintext email representations of a UserDigest.
func RenderDigestEmail(u domainuser.User, d domaindigest.UserDigest, baseURL string) (subject, textBody, htmlBody string, err error) {
	baseURL = strings.TrimRight(baseURL, "/")
	if baseURL == "" {
		baseURL = "https://athena.dev"
	}

	name := strings.TrimSpace(u.DisplayName)
	if name == "" {
		name = "Researcher"
	}

	dateStr := d.GeneratedAt.Format("Jan 02, 2006")
	subject = fmt.Sprintf("🔬 Athena Weekly Briefing — %s", dateStr)

	// 1. Plaintext Body
	var txt strings.Builder
	txt.WriteString(fmt.Sprintf("ATHENA SCIENTIFIC RESEARCH BRIEFING\n"))
	txt.WriteString(fmt.Sprintf("Week of %s\n\n", dateStr))
	txt.WriteString(fmt.Sprintf("Hello %s,\n\n", name))

	if strings.TrimSpace(d.AISummary) != "" {
		txt.WriteString("--- EXECUTIVE AI SYNTHESIS ---\n")
		txt.WriteString(d.AISummary + "\n\n")
	}

	if len(d.TopTakeaways) > 0 {
		txt.WriteString("--- KEY EMPIRICAL TAKEAWAYS ---\n")
		for _, t := range d.TopTakeaways {
			txt.WriteString(fmt.Sprintf("• %s\n", t))
		}
		txt.WriteString("\n")
	}

	if len(d.Sections) > 0 {
		txt.WriteString("--- CURATED PAPERS ACROSS YOUR TOPICS ---\n")
		for _, sec := range d.Sections {
			txt.WriteString(fmt.Sprintf("\n## %s\n", sec.Title))
			if sec.Description != "" {
				txt.WriteString(sec.Description + "\n")
			}
			for i, p := range sec.Papers {
				txt.WriteString(fmt.Sprintf("%d. %s (%d)\n", i+1, p.Title, p.Year))
				meta := []string{}
				if p.VenueName != "" {
					meta = append(meta, p.VenueName)
				}
				if p.CitedByCount > 0 {
					meta = append(meta, fmt.Sprintf("%d citations", p.CitedByCount))
				}
				if len(meta) > 0 {
					txt.WriteString(fmt.Sprintf("   %s\n", strings.Join(meta, " · ")))
				}
				txt.WriteString(fmt.Sprintf("   Read: %s/papers/%s\n", baseURL, p.ID.String()))
			}
		}
		txt.WriteString("\n")
	}

	if len(d.Pulses) > 0 {
		txt.WriteString("--- TOPIC MOMENTUM ---\n")
		for _, p := range d.Pulses {
			txt.WriteString(fmt.Sprintf("• %s (%d papers): %s\n",
				p.TopicName, p.PaperCount, strings.Join(p.KeyThemes, ", ")))
		}
		txt.WriteString("\n")
	}

	txt.WriteString(fmt.Sprintf("---\nSent to %s by Athena Research Intelligence.\n", u.Email))
	txt.WriteString(fmt.Sprintf("Explore more at %s\n", baseURL))
	textBody = txt.String()

	// 2. HTML Body
	htmlData := struct {
		Name        string
		DateStr     string
		AISummary   string
		SummaryPs   []string
		Takeaways   []string
		Sections    []domaindigest.DigestSection
		Pulses      []domaindigest.TopicPulse
		BaseURL     string
		Email       string
	}{
		Name:      name,
		DateStr:   dateStr,
		AISummary: d.AISummary,
		SummaryPs: splitParagraphs(d.AISummary),
		Takeaways: d.TopTakeaways,
		Sections:  d.Sections,
		Pulses:    d.Pulses,
		BaseURL:   baseURL,
		Email:     u.Email,
	}

	tmpl, err := template.New("digest_email").Funcs(template.FuncMap{
		"escape": html.EscapeString,
		"paperURL": func(paperID fmt.Stringer) string {
			return fmt.Sprintf("%s/papers/%s", baseURL, paperID.String())
		},
	}).Parse(digestHTMLTemplate)
	if err != nil {
		return "", "", "", fmt.Errorf("parse digest template: %w", err)
	}

	var htmlBuf bytes.Buffer
	if err := tmpl.Execute(&htmlBuf, htmlData); err != nil {
		return "", "", "", fmt.Errorf("execute digest template: %w", err)
	}

	htmlBody = htmlBuf.String()
	return subject, textBody, htmlBody, nil
}

func splitParagraphs(s string) []string {
	var out []string
	raw := strings.Split(s, "\n\n")
	for _, p := range raw {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

const digestHTMLTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Athena Weekly Research Briefing</title>
  <style>
    body {
      margin: 0; padding: 0; background-color: #0B0D11; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E5E7EB; -webkit-font-smoothing: antialiased;
    }
    .wrapper { width: 100%; table-layout: fixed; background-color: #0B0D11; padding: 32px 0; }
    .content { max-width: 620px; margin: 0 auto; background-color: #15181F; border: 1px solid #232732; border-radius: 14px; overflow: hidden; }
    .header { padding: 32px 32px 24px 32px; background: linear-gradient(180deg, #1A1E29 0%, #15181F 100%); border-bottom: 1px solid #232732; text-align: left; }
    .brand-row { display: flex; align-items: center; margin-bottom: 8px; }
    .logo-text { font-size: 13px; font-weight: 700; letter-spacing: 2px; color: #FF7675; text-transform: uppercase; }
    .briefing-title { font-size: 24px; font-weight: 800; color: #FFFFFF; margin: 4px 0 6px 0; line-height: 1.25; }
    .date-badge { font-size: 13px; color: #9CA3AF; }
    .body-section { padding: 28px 32px; }
    .greeting { font-size: 16px; color: #D1D5DB; margin-bottom: 24px; }
    .ai-card { background: #11141A; border: 1px solid #FF7675; border-radius: 10px; padding: 20px 22px; margin-bottom: 28px; }
    .ai-badge { font-size: 11px; font-weight: 700; letter-spacing: 1.5px; color: #FF7675; text-transform: uppercase; margin-bottom: 10px; }
    .ai-text { font-size: 14.5px; line-height: 1.6; color: #E5E7EB; margin: 0 0 12px 0; }
    .ai-text:last-child { margin-bottom: 0; }
    .section-title { font-size: 17px; font-weight: 700; color: #FFFFFF; margin: 28px 0 16px 0; display: flex; align-items: center; border-bottom: 1px solid #232732; padding-bottom: 8px; }
    .takeaway-list { margin: 0 0 28px 0; padding-left: 20px; }
    .takeaway-item { font-size: 14px; line-height: 1.55; color: #D1D5DB; margin-bottom: 10px; }
    .paper-card { background: #1A1E29; border: 1px solid #282E3D; border-radius: 9px; padding: 16px 18px; margin-bottom: 14px; }
    .paper-title { font-size: 15px; font-weight: 600; color: #FFFFFF; text-decoration: none; display: block; margin-bottom: 6px; line-height: 1.35; }
    .paper-title:hover { color: #FF7675; }
    .paper-meta { font-size: 12.5px; color: #9CA3AF; line-height: 1.4; }
    .oa-badge { display: inline-block; background-color: #10B981; color: #042F2E; font-size: 10.5px; font-weight: 700; padding: 2px 6px; border-radius: 4px; margin-left: 6px; }
    .pulse-container { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
    .pulse-pill { background: #1C212D; border: 1px solid #2D3446; border-radius: 6px; padding: 6px 10px; font-size: 12px; color: #D1D5DB; }
    .pulse-name { font-weight: 600; color: #FFFFFF; }
    .cta-container { text-align: center; margin: 36px 0 16px 0; }
    .cta-button { display: inline-block; background-color: #FF7675; color: #15181F; font-size: 14px; font-weight: 700; padding: 12px 28px; border-radius: 8px; text-decoration: none; letter-spacing: 0.5px; }
    .footer { padding: 24px 32px; background-color: #101217; border-top: 1px solid #1E222B; text-align: center; font-size: 12px; color: #6B7280; line-height: 1.5; }
    .footer-link { color: #9CA3AF; text-decoration: underline; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="content">
      <div class="header">
        <div class="logo-text">✨ Athena Research</div>
        <div class="briefing-title">Weekly Research Briefing</div>
        <div class="date-badge">Curated scientific briefing for {{.DateStr}}</div>
      </div>
      <div class="body-section">
        <div class="greeting">Hello {{.Name}}, here is your tailored intelligence digest across the literature.</div>

        {{if .SummaryPs}}
        <div class="ai-card">
          <div class="ai-badge">✨ Executive AI Weekly Synthesis</div>
          {{range .SummaryPs}}
          <p class="ai-text">{{.}}</p>
          {{end}}
        </div>
        {{end}}

        {{if .Takeaways}}
        <div class="section-title">Key Empirical Takeaways</div>
        <ul class="takeaway-list">
          {{range .Takeaways}}
          <li class="takeaway-item">{{.}}</li>
          {{end}}
        </ul>
        {{end}}

        {{if .Sections}}
        <div class="section-title">Curated Discoveries</div>
        {{range .Sections}}
          <div style="font-size: 14px; font-weight: 600; color: #FF7675; margin: 16px 0 8px 0;">{{.Title}}</div>
          {{if .Description}}<div style="font-size: 12.5px; color: #9CA3AF; margin-bottom: 12px;">{{.Description}}</div>{{end}}
          {{range .Papers}}
          <div class="paper-card">
            <a class="paper-title" href="{{$.BaseURL}}/papers/{{.ID}}">{{.Title}}</a>
            <div class="paper-meta">
              {{if .Year}}{{.Year}}{{end}}
              {{if .VenueName}} &bull; {{.VenueName}}{{end}}
              {{if .CitedByCount}} &bull; {{.CitedByCount}} citations{{end}}
              {{if .IsOpenAccess}}<span class="oa-badge">OPEN ACCESS</span>{{end}}
            </div>
          </div>
          {{end}}
        {{end}}
        {{end}}

        {{if .Pulses}}
        <div class="section-title">Topic Velocity & Momentum</div>
        <div class="pulse-container">
          {{range .Pulses}}
          <div class="pulse-pill">
            <span class="pulse-name">{{.TopicName}}</span> ({{.PaperCount}} papers)
          </div>
          {{end}}
        </div>
        {{end}}

        <div class="cta-container">
          <a class="cta-button" href="{{.BaseURL}}/digest">Open in Athena App</a>
        </div>
      </div>

      <div class="footer">
        Delivered to {{.Email}} by the Athena Research Intelligence Platform.<br>
        To manage preferences or unsubscribe, visit your <a class="footer-link" href="{{.BaseURL}}/profile">profile settings</a>.
      </div>
    </div>
  </div>
</body>
</html>`
