package mail

import (
	"bytes"
	"context"
	"fmt"
	"html/template"
	"strings"

	domainuser "athena/backend/internal/domain/user"
)

// RenderPasswordResetEmail creates plaintext and HTML emails for password recovery.
func RenderPasswordResetEmail(u domainuser.User, resetURL string) (subject, textBody, htmlBody string, err error) {
	name := strings.TrimSpace(u.DisplayName)
	if name == "" {
		name = "Researcher"
	}

	subject = "🔐 Athena — Reset Your Password"

	var txt strings.Builder
	txt.WriteString(fmt.Sprintf("Hello %s,\n\n", name))
	txt.WriteString("We received a request to reset your password for your Athena account.\n\n")
	txt.WriteString(fmt.Sprintf("To choose a new password, open the following link (valid for 1 hour):\n%s\n\n", resetURL))
	txt.WriteString("If you did not request a password reset, you can safely ignore this email — your account remains secure.\n\n")
	txt.WriteString("— The Athena Team\n")
	textBody = txt.String()

	data := struct {
		Name     string
		ResetURL string
		Email    string
	}{
		Name:     name,
		ResetURL: resetURL,
		Email:    u.Email,
	}

	tmpl, err := template.New("reset_email").Parse(resetHTMLTemplate)
	if err != nil {
		return "", "", "", fmt.Errorf("parse reset template: %w", err)
	}

	var htmlBuf bytes.Buffer
	if err := tmpl.Execute(&htmlBuf, data); err != nil {
		return "", "", "", fmt.Errorf("execute reset template: %w", err)
	}

	htmlBody = htmlBuf.String()
	return subject, textBody, htmlBody, nil
}

const resetHTMLTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password</title>
  <style>
    body {
      margin: 0; padding: 0; background-color: #0B0D11; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E5E7EB; -webkit-font-smoothing: antialiased;
    }
    .wrapper { width: 100%; table-layout: fixed; background-color: #0B0D11; padding: 32px 0; }
    .content { max-width: 540px; margin: 0 auto; background-color: #15181F; border: 1px solid #232732; border-radius: 14px; overflow: hidden; }
    .header { padding: 32px 32px 20px 32px; background: linear-gradient(180deg, #1A1E29 0%, #15181F 100%); border-bottom: 1px solid #232732; text-align: left; }
    .logo-text { font-size: 13px; font-weight: 700; letter-spacing: 2px; color: #FF7675; text-transform: uppercase; margin-bottom: 8px; }
    .title { font-size: 22px; font-weight: 800; color: #FFFFFF; margin: 0; }
    .body { padding: 28px 32px; font-size: 14.5px; line-height: 1.6; color: #D1D5DB; }
    .btn-container { text-align: center; margin: 28px 0; }
    .btn { display: inline-block; background-color: #FF7675; color: #15181F; font-size: 14px; font-weight: 700; padding: 12px 28px; border-radius: 8px; text-decoration: none; }
    .link-box { word-break: break-all; font-size: 12.5px; color: #9CA3AF; background-color: #0F1217; border: 1px solid #232732; padding: 10px 12px; border-radius: 6px; margin: 20px 0; }
    .footer { padding: 20px 32px; background-color: #101217; border-top: 1px solid #1E222B; text-align: center; font-size: 12px; color: #6B7280; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="content">
      <div class="header">
        <div class="logo-text">✨ Athena Research</div>
        <div class="title">Password Reset Request</div>
      </div>
      <div class="body">
        <p>Hello {{.Name}},</p>
        <p>We received a request to reset your password for your Athena account ({{.Email}}). Click the button below to choose a new password:</p>
        <div class="btn-container">
          <a class="btn" href="{{.ResetURL}}">Reset My Password</a>
        </div>
        <p>This password reset link is valid for <strong>1 hour</strong>. If the button doesn't work, copy and paste this link into your browser:</p>
        <div class="link-box">{{.ResetURL}}</div>
        <p style="font-size: 13px; color: #9CA3AF;">If you did not request a password reset, you can safely disregard this email. Your password will not change.</p>
      </div>
      <div class="footer">
        Sent by the Athena Research Intelligence Platform.
      </div>
    </div>
  </div>
</body>
</html>`
