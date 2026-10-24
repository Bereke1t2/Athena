// Command migrate applies pending database migrations using embedded SQL files.
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"athena/backend/migrations"
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("migration failed: %v", err)
	}
}

func run() error {
	// Prioritize direct unpooled connection per Neon best practices.
	dbURL := strings.TrimSpace(os.Getenv("DATABASE_URL_UNPOOLED"))
	if dbURL == "" {
		dbURL = strings.TrimSpace(os.Getenv("ATHENA_DATABASE_URL"))
	}
	if dbURL == "" {
		dbURL = strings.TrimSpace(os.Getenv("DATABASE_URL"))
	}
	if dbURL == "" {
		return fmt.Errorf("no database URL configured (checked DATABASE_URL_UNPOOLED, ATHENA_DATABASE_URL, DATABASE_URL)")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	return migrations.Apply(ctx, dbURL)
}
