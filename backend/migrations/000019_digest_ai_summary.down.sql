-- Migration 000019 down: Remove ai_summary from user_digests
ALTER TABLE user_digests DROP COLUMN IF EXISTS ai_summary;
