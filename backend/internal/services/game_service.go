// Package services contains business logic for the application.
package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/repository"
)

// GameService handles game business logic.
type GameService struct {
	gameRepo *repository.GameRepository
	moveRepo *repository.MoveRepository
	userRepo *repository.UserRepository
}

// NewGameService creates a new GameService.
func NewGameService(
	gameRepo *repository.GameRepository,
	moveRepo *repository.MoveRepository,
	userRepo *repository.UserRepository,
) *GameService {
	return &GameService{
		gameRepo: gameRepo,
		moveRepo: moveRepo,
		userRepo: userRepo,
	}
}

// CreateGame creates a new game between two players.
func (s *GameService) CreateGame(ctx context.Context, redPlayerID, blackPlayerID string, turnTimeout int) (*models.Game, error) {
	game := &models.Game{
		ID:                      uuid.New().String(),
		RedPlayerID:             redPlayerID,
		BlackPlayerID:           blackPlayerID,
		Status:                  models.GameStatusActive,
		TurnTimeoutSeconds:      turnTimeout,
		RedRollbacksRemaining:   3,
		BlackRollbacksRemaining: 3,
		TotalMoves:              0,
	}

	if err := s.gameRepo.Create(ctx, game); err != nil {
		return nil, fmt.Errorf("failed to create game: %w", err)
	}

	return game, nil
}

// GetGame retrieves a game by ID.
func (s *GameService) GetGame(ctx context.Context, gameID string) (*models.Game, error) {
	game, err := s.gameRepo.GetByID(ctx, gameID)
	if err != nil {
		if errors.Is(err, repository.ErrGameNotFound) {
			return nil, ErrGameNotFound
		}
		return nil, fmt.Errorf("failed to get game: %w", err)
	}
	return game, nil
}

// GetHistory retrieves a player's game history.
func (s *GameService) GetHistory(ctx context.Context, playerID string, page, pageSize int) ([]*models.Game, int, error) {
	offset := (page - 1) * pageSize

	games, err := s.gameRepo.GetHistoryByPlayer(ctx, playerID, pageSize, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get history: %w", err)
	}

	total, err := s.gameRepo.CountByPlayer(ctx, playerID)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count games: %w", err)
	}

	return games, total, nil
}

// GetMoves retrieves all moves for a game.
func (s *GameService) GetMoves(ctx context.Context, gameID string) ([]*models.Move, error) {
	moves, err := s.moveRepo.GetByGameID(ctx, gameID)
	if err != nil {
		return nil, fmt.Errorf("failed to get moves: %w", err)
	}
	return moves, nil
}

// RecordMove records a move in a game.
func (s *GameService) RecordMove(ctx context.Context, move *models.Move) error {
	move.Timestamp = time.Now()

	if err := s.moveRepo.Create(ctx, move); err != nil {
		return fmt.Errorf("failed to record move: %w", err)
	}

	// Update game's total moves
	game, err := s.gameRepo.GetByID(ctx, move.GameID)
	if err != nil {
		return fmt.Errorf("failed to get game: %w", err)
	}

	game.TotalMoves++
	if err := s.gameRepo.Update(ctx, game); err != nil {
		return fmt.Errorf("failed to update game: %w", err)
	}

	return nil
}

// EndGame ends a game with the specified result.
func (s *GameService) EndGame(ctx context.Context, gameID string, winnerID *string, resultType models.ResultType) error {
	game, err := s.gameRepo.GetByID(ctx, gameID)
	if err != nil {
		return fmt.Errorf("failed to get game: %w", err)
	}

	now := time.Now()
	game.Status = models.GameStatusCompleted
	game.WinnerID = winnerID
	game.ResultType = &resultType
	game.CompletedAt = &now

	if err := s.gameRepo.Update(ctx, game); err != nil {
		return fmt.Errorf("failed to update game: %w", err)
	}

	// Update player stats
	var redResult, blackResult GameResult
	if winnerID == nil {
		redResult = GameResultDraw
		blackResult = GameResultDraw
	} else if *winnerID == game.RedPlayerID {
		redResult = GameResultWin
		blackResult = GameResultLoss
	} else {
		redResult = GameResultLoss
		blackResult = GameResultWin
	}

	userService := NewUserService(s.userRepo)
	_ = userService.UpdateStats(ctx, game.RedPlayerID, redResult)
	_ = userService.UpdateStats(ctx, game.BlackPlayerID, blackResult)

	return nil
}

// UseRollback decrements a player's rollback count.
func (s *GameService) UseRollback(ctx context.Context, gameID, playerID string) error {
	game, err := s.gameRepo.GetByID(ctx, gameID)
	if err != nil {
		return fmt.Errorf("failed to get game: %w", err)
	}

	if playerID == game.RedPlayerID {
		if game.RedRollbacksRemaining <= 0 {
			return ErrNoRollbacksRemaining
		}
		game.RedRollbacksRemaining--
	} else if playerID == game.BlackPlayerID {
		if game.BlackRollbacksRemaining <= 0 {
			return ErrNoRollbacksRemaining
		}
		game.BlackRollbacksRemaining--
	} else {
		return ErrPlayerNotInGame
	}

	if err := s.gameRepo.Update(ctx, game); err != nil {
		return fmt.Errorf("failed to update game: %w", err)
	}

	return nil
}

// RevertToMove reverts a game to a specific move number.
func (s *GameService) RevertToMove(ctx context.Context, gameID string, moveNumber int) error {
	// Delete all moves after the specified move number
	if err := s.moveRepo.DeleteAfterMoveNumber(ctx, gameID, moveNumber); err != nil {
		return fmt.Errorf("failed to delete moves: %w", err)
	}

	// Update game's total moves
	game, err := s.gameRepo.GetByID(ctx, gameID)
	if err != nil {
		return fmt.Errorf("failed to get game: %w", err)
	}

	game.TotalMoves = moveNumber
	if err := s.gameRepo.Update(ctx, game); err != nil {
		return fmt.Errorf("failed to update game: %w", err)
	}

	return nil
}

// GetActiveGames retrieves active games for a player.
func (s *GameService) GetActiveGames(ctx context.Context, playerID string) ([]*models.Game, error) {
	games, err := s.gameRepo.GetActiveByPlayer(ctx, playerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get active games: %w", err)
	}
	return games, nil
}

// Service errors
var (
	ErrGameNotFound         = errors.New("game not found")
	ErrPlayerNotInGame      = errors.New("player is not in this game")
	ErrNoRollbacksRemaining = errors.New("no rollbacks remaining")
	ErrNotPlayerTurn        = errors.New("not player's turn")
	ErrInvalidMove          = errors.New("invalid move")
)
