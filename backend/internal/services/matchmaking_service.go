// Package services contains business logic for the application.
package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/repository"
)

const (
	matchmakingQueueKey   = "matchmaking:queue"
	matchmakingPlayerKey  = "matchmaking:player:"
	matchmakingResultKey  = "matchmaking:result:"
	matchmakingTTL        = 5 * time.Minute
)

// MatchmakingService handles matchmaking logic.
type MatchmakingService struct {
	redis       *repository.RedisClient
	gameService *GameService
}

// NewMatchmakingService creates a new MatchmakingService.
func NewMatchmakingService(redis *repository.RedisClient, gameService *GameService) *MatchmakingService {
	return &MatchmakingService{
		redis:       redis,
		gameService: gameService,
	}
}

// JoinQueue adds a player to the matchmaking queue.
func (s *MatchmakingService) JoinQueue(ctx context.Context, entry *models.MatchmakingEntry) (*QueueStatus, error) {
	// Check if player is already in queue
	existing, err := s.GetPlayerEntry(ctx, entry.DeviceID)
	if err == nil && existing != nil {
		return nil, ErrAlreadyInQueue
	}

	entry.JoinedAt = time.Now()

	// Store player entry
	entryJSON, err := json.Marshal(entry)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal entry: %w", err)
	}

	// Add to sorted set (score is timestamp for FIFO ordering)
	score := float64(entry.JoinedAt.UnixNano())
	if err := s.redis.Client().ZAdd(ctx, matchmakingQueueKey, redis.Z{
		Score:  score,
		Member: entry.DeviceID,
	}).Err(); err != nil {
		return nil, fmt.Errorf("failed to add to queue: %w", err)
	}

	// Store entry details
	if err := s.redis.Client().Set(ctx, matchmakingPlayerKey+entry.DeviceID, entryJSON, matchmakingTTL).Err(); err != nil {
		return nil, fmt.Errorf("failed to store entry: %w", err)
	}

	// Try to find a match
	match, err := s.tryMatch(ctx, entry)
	if err != nil {
		// No match found, return queue status
		position, _ := s.getQueuePosition(ctx, entry.DeviceID)
		return &QueueStatus{
			Status:              StatusWaiting,
			Position:            position,
			EstimatedWaitSeconds: estimateWaitTime(position),
		}, nil
	}

	return match, nil
}

// LeaveQueue removes a player from the matchmaking queue.
func (s *MatchmakingService) LeaveQueue(ctx context.Context, deviceID string) error {
	// Remove from sorted set
	if err := s.redis.Client().ZRem(ctx, matchmakingQueueKey, deviceID).Err(); err != nil {
		return fmt.Errorf("failed to remove from queue: %w", err)
	}

	// Remove entry details
	if err := s.redis.Client().Del(ctx, matchmakingPlayerKey+deviceID).Err(); err != nil {
		return fmt.Errorf("failed to remove entry: %w", err)
	}

	return nil
}

// GetStatus returns the current queue status for a player.
func (s *MatchmakingService) GetStatus(ctx context.Context, deviceID string) (*QueueStatus, error) {
	// Check if there's a match result
	resultJSON, err := s.redis.Client().Get(ctx, matchmakingResultKey+deviceID).Bytes()
	if err == nil {
		var result QueueStatus
		if err := json.Unmarshal(resultJSON, &result); err == nil {
			return &result, nil
		}
	}

	// Check if player is in queue
	position, err := s.getQueuePosition(ctx, deviceID)
	if err != nil {
		return &QueueStatus{Status: StatusIdle}, nil
	}

	return &QueueStatus{
		Status:              StatusWaiting,
		Position:            position,
		EstimatedWaitSeconds: estimateWaitTime(position),
	}, nil
}

// GetPlayerEntry retrieves a player's matchmaking entry.
func (s *MatchmakingService) GetPlayerEntry(ctx context.Context, deviceID string) (*models.MatchmakingEntry, error) {
	entryJSON, err := s.redis.Client().Get(ctx, matchmakingPlayerKey+deviceID).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, ErrNotInQueue
		}
		return nil, fmt.Errorf("failed to get entry: %w", err)
	}

	var entry models.MatchmakingEntry
	if err := json.Unmarshal(entryJSON, &entry); err != nil {
		return nil, fmt.Errorf("failed to unmarshal entry: %w", err)
	}

	return &entry, nil
}

// tryMatch attempts to find a match for the given player.
func (s *MatchmakingService) tryMatch(ctx context.Context, entry *models.MatchmakingEntry) (*QueueStatus, error) {
	// Get all players in queue (excluding current player)
	members, err := s.redis.Client().ZRange(ctx, matchmakingQueueKey, 0, -1).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to get queue: %w", err)
	}

	for _, memberID := range members {
		if memberID == entry.DeviceID {
			continue
		}

		opponent, err := s.GetPlayerEntry(ctx, memberID)
		if err != nil {
			continue
		}

		// Simple matching: just pair any two players
		// In production, you might match by timeout preference, skill level, etc.
		game, err := s.createMatch(ctx, entry, opponent)
		if err != nil {
			continue
		}

		return game, nil
	}

	return nil, ErrNoMatchFound
}

// createMatch creates a game between two matched players.
func (s *MatchmakingService) createMatch(ctx context.Context, player1, player2 *models.MatchmakingEntry) (*QueueStatus, error) {
	// Randomly assign colors
	var redPlayer, blackPlayer *models.MatchmakingEntry
	if rand.Intn(2) == 0 {
		redPlayer = player1
		blackPlayer = player2
	} else {
		redPlayer = player2
		blackPlayer = player1
	}

	// Use the shorter timeout preference
	timeout := player1.TurnTimeout
	if player2.TurnTimeout < timeout && player2.TurnTimeout > 0 {
		timeout = player2.TurnTimeout
	}

	// Create game
	game, err := s.gameService.CreateGame(ctx, redPlayer.DeviceID, blackPlayer.DeviceID, timeout)
	if err != nil {
		return nil, fmt.Errorf("failed to create game: %w", err)
	}

	// Remove both players from queue
	s.LeaveQueue(ctx, player1.DeviceID)
	s.LeaveQueue(ctx, player2.DeviceID)

	// Store match results for both players
	player1Color := models.PlayerColorRed
	player2Color := models.PlayerColorBlack
	if redPlayer.DeviceID == player2.DeviceID {
		player1Color = models.PlayerColorBlack
		player2Color = models.PlayerColorRed
	}

	result1 := &QueueStatus{
		Status:       StatusMatched,
		GameID:       game.ID,
		OpponentID:   player2.DeviceID,
		OpponentName: player2.DisplayName,
		YourColor:    player1Color,
	}

	result2 := &QueueStatus{
		Status:       StatusMatched,
		GameID:       game.ID,
		OpponentID:   player1.DeviceID,
		OpponentName: player1.DisplayName,
		YourColor:    player2Color,
	}

	// Store results
	result1JSON, _ := json.Marshal(result1)
	result2JSON, _ := json.Marshal(result2)
	s.redis.Client().Set(ctx, matchmakingResultKey+player1.DeviceID, result1JSON, matchmakingTTL)
	s.redis.Client().Set(ctx, matchmakingResultKey+player2.DeviceID, result2JSON, matchmakingTTL)

	return result1, nil
}

func (s *MatchmakingService) getQueuePosition(ctx context.Context, deviceID string) (int, error) {
	rank, err := s.redis.Client().ZRank(ctx, matchmakingQueueKey, deviceID).Result()
	if err != nil {
		return 0, err
	}
	return int(rank) + 1, nil
}

func estimateWaitTime(position int) int {
	// Simple estimate: 10 seconds per position in queue
	return position * 10
}

// QueueStatus represents the current matchmaking status.
type QueueStatus struct {
	Status              MatchStatus       `json:"status"`
	Position            int               `json:"position,omitempty"`
	EstimatedWaitSeconds int              `json:"estimated_wait_seconds,omitempty"`
	GameID              string            `json:"game_id,omitempty"`
	OpponentID          string            `json:"opponent_id,omitempty"`
	OpponentName        string            `json:"opponent_name,omitempty"`
	YourColor           models.PlayerColor `json:"your_color,omitempty"`
}

// MatchStatus represents the status of matchmaking.
type MatchStatus string

const (
	StatusIdle    MatchStatus = "idle"
	StatusWaiting MatchStatus = "waiting"
	StatusMatched MatchStatus = "matched"
	StatusLeft    MatchStatus = "left"
)

// Matchmaking errors
var (
	ErrAlreadyInQueue = errors.New("player is already in queue")
	ErrNotInQueue     = errors.New("player is not in queue")
	ErrNoMatchFound   = errors.New("no match found")
)
