-- Migration 000019: Add ai_summary to user_digests
ALTER TABLE user_digests ADD COLUMN IF NOT EXISTS ai_summary text NOT NULL DEFAULT '';
