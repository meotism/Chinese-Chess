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

// ErrGameNotFound is returned when a game is not found.
var ErrGameNotFound = errors.New("game not found")

// GameRepository handles game database operations.
type GameRepository struct {
	db *PostgresDB
}

// NewGameRepository creates a new GameRepository.
func NewGameRepository(db *PostgresDB) *GameRepository {
	return &GameRepository{db: db}
}

// Create creates a new game.
func (r *GameRepository) Create(ctx context.Context, game *models.Game) error {
	query := `
		INSERT INTO games (
			id, red_player_id, black_player_id, status, winner_id, result_type,
			turn_timeout_seconds, red_rollbacks_remaining, black_rollbacks_remaining,
			total_moves, created_at, completed_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	game.CreatedAt = time.Now()

	_, err := r.db.Pool().Exec(ctx, query,
		game.ID,
		game.RedPlayerID,
		game.BlackPlayerID,
		game.Status,
		game.WinnerID,
		game.ResultType,
		game.TurnTimeoutSeconds,
		game.RedRollbacksRemaining,
		game.BlackRollbacksRemaining,
		game.TotalMoves,
		game.CreatedAt,
		game.CompletedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create game: %w", err)
	}

	return nil
}

// GetByID retrieves a game by its ID.
func (r *GameRepository) GetByID(ctx context.Context, id string) (*models.Game, error) {
	query := `
		SELECT id, red_player_id, black_player_id, status, winner_id, result_type,
			   turn_timeout_seconds, red_rollbacks_remaining, black_rollbacks_remaining,
			   total_moves, created_at, completed_at
		FROM games
		WHERE id = $1
	`

	var game models.Game
	err := r.db.Pool().QueryRow(ctx, query, id).Scan(
		&game.ID,
		&game.RedPlayerID,
		&game.BlackPlayerID,
		&game.Status,
		&game.WinnerID,
		&game.ResultType,
		&game.TurnTimeoutSeconds,
		&game.RedRollbacksRemaining,
		&game.BlackRollbacksRemaining,
		&game.TotalMoves,
		&game.CreatedAt,
		&game.CompletedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrGameNotFound
		}
		return nil, fmt.Errorf("failed to get game: %w", err)
	}

	return &game, nil
}

// Update updates a game.
func (r *GameRepository) Update(ctx context.Context, game *models.Game) error {
	query := `
		UPDATE games
		SET status = $2, winner_id = $3, result_type = $4,
			red_rollbacks_remaining = $5, black_rollbacks_remaining = $6,
			total_moves = $7, completed_at = $8
		WHERE id = $1
	`

	result, err := r.db.Pool().Exec(ctx, query,
		game.ID,
		game.Status,
		game.WinnerID,
		game.ResultType,
		game.RedRollbacksRemaining,
		game.BlackRollbacksRemaining,
		game.TotalMoves,
		game.CompletedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to update game: %w", err)
	}

	if result.RowsAffected() == 0 {
		return ErrGameNotFound
	}

	return nil
}

// GetHistoryByPlayer retrieves a player's game history with pagination.
func (r *GameRepository) GetHistoryByPlayer(ctx context.Context, playerID string, limit, offset int) ([]*models.Game, error) {
	query := `
		SELECT id, red_player_id, black_player_id, status, winner_id, result_type,
			   turn_timeout_seconds, red_rollbacks_remaining, black_rollbacks_remaining,
			   total_moves, created_at, completed_at
		FROM games
		WHERE (red_player_id = $1 OR black_player_id = $1)
		  AND status = 'completed'
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Pool().Query(ctx, query, playerID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get game history: %w", err)
	}
	defer rows.Close()

	var games []*models.Game
	for rows.Next() {
		var game models.Game
		err := rows.Scan(
			&game.ID,
			&game.RedPlayerID,
			&game.BlackPlayerID,
			&game.Status,
			&game.WinnerID,
			&game.ResultType,
			&game.TurnTimeoutSeconds,
			&game.RedRollbacksRemaining,
			&game.BlackRollbacksRemaining,
			&game.TotalMoves,
			&game.CreatedAt,
			&game.CompletedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan game: %w", err)
		}
		games = append(games, &game)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating game rows: %w", err)
	}

	return games, nil
}

// CountByPlayer returns the total number of games for a player.
func (r *GameRepository) CountByPlayer(ctx context.Context, playerID string) (int, error) {
	query := `
		SELECT COUNT(*)
		FROM games
		WHERE (red_player_id = $1 OR black_player_id = $1)
		  AND status = 'completed'
	`

	var count int
	err := r.db.Pool().QueryRow(ctx, query, playerID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to count games: %w", err)
	}

	return count, nil
}

// GetActiveByPlayer retrieves active games for a player.
func (r *GameRepository) GetActiveByPlayer(ctx context.Context, playerID string) ([]*models.Game, error) {
	query := `
		SELECT id, red_player_id, black_player_id, status, winner_id, result_type,
			   turn_timeout_seconds, red_rollbacks_remaining, black_rollbacks_remaining,
			   total_moves, created_at, completed_at
		FROM games
		WHERE (red_player_id = $1 OR black_player_id = $1)
		  AND status = 'active'
		ORDER BY created_at DESC
	`

	rows, err := r.db.Pool().Query(ctx, query, playerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active games: %w", err)
	}
	defer rows.Close()

	var games []*models.Game
	for rows.Next() {
		var game models.Game
		err := rows.Scan(
			&game.ID,
			&game.RedPlayerID,
			&game.BlackPlayerID,
			&game.Status,
			&game.WinnerID,
			&game.ResultType,
			&game.TurnTimeoutSeconds,
			&game.RedRollbacksRemaining,
			&game.BlackRollbacksRemaining,
			&game.TotalMoves,
			&game.CreatedAt,
			&game.CompletedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan game: %w", err)
		}
		games = append(games, &game)
	}

	return games, nil
}
