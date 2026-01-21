// Package repository handles database operations.
package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// ErrUserNotFound is returned when a user is not found.
var ErrUserNotFound = errors.New("user not found")

// UserRepository handles user database operations.
type UserRepository struct {
	db *PostgresDB
}

// NewUserRepository creates a new UserRepository.
func NewUserRepository(db *PostgresDB) *UserRepository {
	return &UserRepository{db: db}
}

// Create creates a new user.
func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (id, display_name, total_games, wins, losses, draws, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	now := time.Now()
	user.CreatedAt = now
	user.UpdatedAt = now

	_, err := r.db.Pool().Exec(ctx, query,
		user.ID,
		user.DisplayName,
		user.TotalGames,
		user.Wins,
		user.Losses,
		user.Draws,
		user.CreatedAt,
		user.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

// GetByID retrieves a user by their device ID.
func (r *UserRepository) GetByID(ctx context.Context, id string) (*models.User, error) {
	query := `
		SELECT id, display_name, total_games, wins, losses, draws, created_at, updated_at
		FROM users
		WHERE id = $1
	`

	var user models.User
	err := r.db.Pool().QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.DisplayName,
		&user.TotalGames,
		&user.Wins,
		&user.Losses,
		&user.Draws,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

// Update updates a user's profile.
func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET display_name = $2, updated_at = $3
		WHERE id = $1
	`

	user.UpdatedAt = time.Now()

	result, err := r.db.Pool().Exec(ctx, query,
		user.ID,
		user.DisplayName,
		user.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	if result.RowsAffected() == 0 {
		return ErrUserNotFound
	}

	return nil
}

// UpdateStats updates a user's game statistics.
func (r *UserRepository) UpdateStats(ctx context.Context, id string, stats models.UserStats) error {
	query := `
		UPDATE users
		SET total_games = $2, wins = $3, losses = $4, draws = $5, updated_at = $6
		WHERE id = $1
	`

	result, err := r.db.Pool().Exec(ctx, query,
		id,
		stats.TotalGames,
		stats.Wins,
		stats.Losses,
		stats.Draws,
		time.Now(),
	)

	if err != nil {
		return fmt.Errorf("failed to update user stats: %w", err)
	}

	if result.RowsAffected() == 0 {
		return ErrUserNotFound
	}

	return nil
}

// Exists checks if a user with the given ID exists.
func (r *UserRepository) Exists(ctx context.Context, id string) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)`

	var exists bool
	err := r.db.Pool().QueryRow(ctx, query, id).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check user existence: %w", err)
	}

	return exists, nil
}
