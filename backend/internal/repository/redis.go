// Package repository handles database operations.
package repository

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"

	"github.com/xiangqi/chinese-chess-backend/internal/config"
)

// RedisClient wraps a Redis client.
type RedisClient struct {
	client *redis.Client
}

// NewRedisClient creates a new Redis client.
func NewRedisClient(cfg config.RedisConfig) (*RedisClient, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Address(),
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	// Test connection
	if err := client.Ping(context.Background()).Err(); err != nil {
		return nil, fmt.Errorf("unable to connect to Redis: %w", err)
	}

	return &RedisClient{client: client}, nil
}

// Client returns the underlying Redis client.
func (r *RedisClient) Client() *redis.Client {
	return r.client
}

// Close closes the Redis client.
func (r *RedisClient) Close() error {
	return r.client.Close()
}
