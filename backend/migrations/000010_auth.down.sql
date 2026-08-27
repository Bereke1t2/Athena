DROP TABLE sessions;
ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
