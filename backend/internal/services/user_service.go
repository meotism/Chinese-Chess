// Package services contains business logic for the application.
package services

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/repository"
)

// UserService handles user business logic.
type UserService struct {
	userRepo *repository.UserRepository
}

// NewUserService creates a new UserService.
func NewUserService(userRepo *repository.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

// Register creates a new user or returns existing user.
func (s *UserService) Register(ctx context.Context, deviceID, displayName string) (*models.User, error) {
	// Check if user already exists
	existing, err := s.userRepo.GetByID(ctx, deviceID)
	if err == nil {
		// User already exists, return it
		return existing, nil
	}
	if !errors.Is(err, repository.ErrUserNotFound) {
		return nil, fmt.Errorf("failed to check existing user: %w", err)
	}

	// Validate display name
	if err := s.ValidateDisplayName(displayName); err != nil {
		return nil, err
	}

	// Create new user
	user := &models.User{
		ID:          deviceID,
		DisplayName: displayName,
		TotalGames:  0,
		Wins:        0,
		Losses:      0,
		Draws:       0,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return user, nil
}

// GetByID retrieves a user by their device ID.
func (s *UserService) GetByID(ctx context.Context, deviceID string) (*models.User, error) {
	user, err := s.userRepo.GetByID(ctx, deviceID)
	if err != nil {
		if errors.Is(err, repository.ErrUserNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	return user, nil
}

// UpdateDisplayName updates a user's display name.
func (s *UserService) UpdateDisplayName(ctx context.Context, deviceID, displayName string) (*models.User, error) {
	// Validate display name
	if err := s.ValidateDisplayName(displayName); err != nil {
		return nil, err
	}

	// Get existing user
	user, err := s.userRepo.GetByID(ctx, deviceID)
	if err != nil {
		if errors.Is(err, repository.ErrUserNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	// Update display name
	user.DisplayName = displayName
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to update user: %w", err)
	}

	return user, nil
}

// UpdateStats updates a user's game statistics.
func (s *UserService) UpdateStats(ctx context.Context, deviceID string, result GameResult) error {
	user, err := s.userRepo.GetByID(ctx, deviceID)
	if err != nil {
		return fmt.Errorf("failed to get user: %w", err)
	}

	user.TotalGames++
	switch result {
	case GameResultWin:
		user.Wins++
	case GameResultLoss:
		user.Losses++
	case GameResultDraw:
		user.Draws++
	}

	return s.userRepo.UpdateStats(ctx, deviceID, user.Stats())
}

// ValidateDisplayName validates a display name.
func (s *UserService) ValidateDisplayName(name string) error {
	// Length check (3-20 characters)
	length := utf8.RuneCountInString(name)
	if length < 3 {
		return ErrDisplayNameTooShort
	}
	if length > 20 {
		return ErrDisplayNameTooLong
	}

	// Character set check (alphanumeric, underscore, hyphen)
	validPattern := regexp.MustCompile(`^[a-zA-Z0-9_-]+$`)
	if !validPattern.MatchString(name) {
		return ErrDisplayNameInvalidChars
	}

	// Reserved words check
	lowercaseName := strings.ToLower(name)
	reservedWords := []string{"admin", "moderator", "system", "null", "undefined"}
	for _, word := range reservedWords {
		if strings.Contains(lowercaseName, word) {
			return ErrDisplayNameReserved
		}
	}

	return nil
}

// GameResult represents the outcome of a game for a player.
type GameResult string

const (
	GameResultWin  GameResult = "win"
	GameResultLoss GameResult = "loss"
	GameResultDraw GameResult = "draw"
)

// Service errors
var (
	ErrUserNotFound            = errors.New("user not found")
	ErrDisplayNameTooShort     = errors.New("display name must be at least 3 characters")
	ErrDisplayNameTooLong      = errors.New("display name must be at most 20 characters")
	ErrDisplayNameInvalidChars = errors.New("display name can only contain letters, numbers, underscores, and hyphens")
	ErrDisplayNameReserved     = errors.New("display name contains a reserved word")
)
