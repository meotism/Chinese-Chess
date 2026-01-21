// Package repository handles database operations.
package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xiangqi/chinese-chess-backend/internal/config"
)

// PostgresDB wraps a PostgreSQL connection pool.
type PostgresDB struct {
	pool *pgxpool.Pool
}

// NewPostgresDB creates a new PostgreSQL database connection.
func NewPostgresDB(cfg config.DatabaseConfig) (*PostgresDB, error) {
	connString := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s&pool_max_conns=%d",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.DBName, cfg.SSLMode, cfg.MaxOpenConns,
	)

	poolConfig, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("unable to parse connection string: %w", err)
	}

	poolConfig.MaxConns = int32(cfg.MaxOpenConns)
	poolConfig.MinConns = int32(cfg.MaxIdleConns)

	pool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
	if err != nil {
		return nil, fmt.Errorf("unable to create connection pool: %w", err)
	}

	// Test connection
	if err := pool.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("unable to ping database: %w", err)
	}

	return &PostgresDB{pool: pool}, nil
}

// Pool returns the underlying connection pool.
func (db *PostgresDB) Pool() *pgxpool.Pool {
	return db.pool
}

// Close closes the database connection pool.
func (db *PostgresDB) Close() {
	db.pool.Close()
}
