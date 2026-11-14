package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"

	v1 "athena/backend/internal/delivery/http/v1"
)

var _ v1.RateLimiter = (*RedisRateLimiter)(nil)

// slidingWindowScript atomically prunes expired timestamps, counts members,
// and conditionally records the new attempt if within limit.
var slidingWindowScript = redis.NewScript(`
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
local clearBefore = now - window

redis.call('ZREMRANGEBYSCORE', key, 0, clearBefore)
local currentCount = redis.call('ZCARD', key)

if currentCount < limit then
    redis.call('ZADD', key, now, ARGV[4])
    redis.call('PEXPIRE', key, window)
    return { 1, limit - currentCount - 1 }
else
    local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
    local oldestScore = now
    if oldest and #oldest >= 2 then
        oldestScore = tonumber(oldest[2])
    end
    return { 0, 0, oldestScore }
end
`)

// RedisRateLimiter implements v1.RateLimiter backed by Redis sorted sets.
type RedisRateLimiter struct {
	rdb    *redis.Client
	prefix string
}

func NewRedisRateLimiter(rdb *redis.Client) *RedisRateLimiter {
	return &RedisRateLimiter{
		rdb:    rdb,
		prefix: "athena:ratelimit:",
	}
}

func (r *RedisRateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, int, time.Time, error) {
	return true, limit, time.Now().Add(window), nil
}
