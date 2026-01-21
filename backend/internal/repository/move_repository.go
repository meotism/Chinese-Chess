// Package repository handles database operations.
package repository

import (
	"context"
	"fmt"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// MoveRepository handles move database operations.
type MoveRepository struct {
	db *PostgresDB
}

// NewMoveRepository creates a new MoveRepository.
func NewMoveRepository(db *PostgresDB) *MoveRepository {
	return &MoveRepository{db: db}
}

// Create creates a new move record.
func (r *MoveRepository) Create(ctx context.Context, move *models.Move) error {
	query := `
		INSERT INTO moves (
			game_id, move_number, player_id, from_position, to_position,
			piece_type, captured_piece, is_check, timestamp
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id
	`

	err := r.db.Pool().QueryRow(ctx, query,
		move.GameID,
		move.MoveNumber,
		move.PlayerID,
		move.FromPosition,
		move.ToPosition,
		move.PieceType,
		move.CapturedPiece,
		move.IsCheck,
		move.Timestamp,
	).Scan(&move.ID)

	if err != nil {
		return fmt.Errorf("failed to create move: %w", err)
	}

	return nil
}

// GetByGameID retrieves all moves for a game in order.
func (r *MoveRepository) GetByGameID(ctx context.Context, gameID string) ([]*models.Move, error) {
	query := `
		SELECT id, game_id, move_number, player_id, from_position, to_position,
			   piece_type, captured_piece, is_check, timestamp
		FROM moves
		WHERE game_id = $1
		ORDER BY move_number ASC
	`

	rows, err := r.db.Pool().Query(ctx, query, gameID)
	if err != nil {
		return nil, fmt.Errorf("failed to get moves: %w", err)
	}
	defer rows.Close()

	var moves []*models.Move
	for rows.Next() {
		var move models.Move
		err := rows.Scan(
			&move.ID,
			&move.GameID,
			&move.MoveNumber,
			&move.PlayerID,
			&move.FromPosition,
			&move.ToPosition,
			&move.PieceType,
			&move.CapturedPiece,
			&move.IsCheck,
			&move.Timestamp,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan move: %w", err)
		}
		moves = append(moves, &move)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating move rows: %w", err)
	}

	return moves, nil
}

// GetLastMove retrieves the last move in a game.
func (r *MoveRepository) GetLastMove(ctx context.Context, gameID string) (*models.Move, error) {
	query := `
		SELECT id, game_id, move_number, player_id, from_position, to_position,
			   piece_type, captured_piece, is_check, timestamp
		FROM moves
		WHERE game_id = $1
		ORDER BY move_number DESC
		LIMIT 1
	`

	var move models.Move
	err := r.db.Pool().QueryRow(ctx, query, gameID).Scan(
		&move.ID,
		&move.GameID,
		&move.MoveNumber,
		&move.PlayerID,
		&move.FromPosition,
		&move.ToPosition,
		&move.PieceType,
		&move.CapturedPiece,
		&move.IsCheck,
		&move.Timestamp,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get last move: %w", err)
	}

	return &move, nil
}

// DeleteAfterMoveNumber deletes all moves after a given move number (for rollback).
func (r *MoveRepository) DeleteAfterMoveNumber(ctx context.Context, gameID string, moveNumber int) error {
	query := `DELETE FROM moves WHERE game_id = $1 AND move_number > $2`

	_, err := r.db.Pool().Exec(ctx, query, gameID, moveNumber)
	if err != nil {
		return fmt.Errorf("failed to delete moves: %w", err)
	}

	return nil
}

// CountByGameID returns the number of moves in a game.
func (r *MoveRepository) CountByGameID(ctx context.Context, gameID string) (int, error) {
	query := `SELECT COUNT(*) FROM moves WHERE game_id = $1`

	var count int
	err := r.db.Pool().QueryRow(ctx, query, gameID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to count moves: %w", err)
	}

	return count, nil
}
