package migrations

import "embed"

// FS contains all embedded schema migration SQL files.
//
//go:embed *.sql
var FS embed.FS
