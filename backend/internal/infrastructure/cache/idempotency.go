package cache

import (
	"context"
	"encoding/json"
	"time"

	"github.com/redis/go-redis/v9"

	v1 "athena/backend/internal/delivery/http/v1"
)

var _ v1.IdempotencyStore = (*RedisIdempotencyStore)(nil)

// RedisIdempotencyStore provides a Redis-backed store for HTTP idempotency replays.
type RedisIdempotencyStore struct {
	rdb    *redis.Client
	prefix string
}

func NewRedisIdempotencyStore(rdb *redis.Client) *RedisIdempotencyStore {
	return &RedisIdempotencyStore{
		rdb:    rdb,
		prefix: "athena:idempotency:",
	}
}

func (s *RedisIdempotencyStore) Get(key string) (*v1.CachedResponse, bool) {
	if s == nil || s.rdb == nil {
		return nil, false
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	data, err := s.rdb.Get(ctx, s.prefix+key).Bytes()
	if err != nil {
		return nil, false
	}

	var resp v1.CachedResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, false
	}

	return &resp, true
}

func (s *RedisIdempotencyStore) Set(key string, resp v1.CachedResponse, ttl time.Duration) {}
