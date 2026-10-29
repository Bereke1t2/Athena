CREATE TABLE user_devices (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       text NOT NULL UNIQUE,
    platform    text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    device_name text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX user_devices_user_idx ON user_devices (user_id);
COMMENT ON TABLE user_devices IS 'Push notification device tokens for mobile and web clients.';
