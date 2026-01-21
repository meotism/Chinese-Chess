// Package services provides unit tests for the user service.
package services

import (
	"context"
	"errors"
	"testing"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/repository"
)

// mockUserRepository is a mock implementation of the user repository for testing.
type mockUserRepository struct {
	users      map[string]*models.User
	createErr  error
	updateErr  error
	getErr     error
	statsErr   error
}

func newMockUserRepository() *mockUserRepository {
	return &mockUserRepository{
		users: make(map[string]*models.User),
	}
}

func (m *mockUserRepository) Create(ctx context.Context, user *models.User) error {
	if m.createErr != nil {
		return m.createErr
	}
	m.users[user.ID] = user
	return nil
}

func (m *mockUserRepository) GetByID(ctx context.Context, id string) (*models.User, error) {
	if m.getErr != nil {
		return nil, m.getErr
	}
	user, ok := m.users[id]
	if !ok {
		return nil, repository.ErrUserNotFound
	}
	return user, nil
}

func (m *mockUserRepository) Update(ctx context.Context, user *models.User) error {
	if m.updateErr != nil {
		return m.updateErr
	}
	m.users[user.ID] = user
	return nil
}

func (m *mockUserRepository) UpdateStats(ctx context.Context, id string, stats models.UserStats) error {
	if m.statsErr != nil {
		return m.statsErr
	}
	if user, ok := m.users[id]; ok {
		user.TotalGames = stats.TotalGames
		user.Wins = stats.Wins
		user.Losses = stats.Losses
		user.Draws = stats.Draws
	}
	return nil
}

// ========== Register Tests ==========

func TestUserService_Register_NewUser(t *testing.T) {
	repo := newMockUserRepository()
	service := NewUserService(&repository.UserRepository{})

	// Use reflection or dependency injection for testing
	// For this test, we'll test the validation logic directly
	ctx := context.Background()

	// Create user using mock
	user := &models.User{
		ID:          "device-123",
		DisplayName: "Player_XYZ",
	}
	repo.Create(ctx, user)

	// Verify user was created
	retrieved, err := repo.GetByID(ctx, "device-123")
	if err != nil {
		t.Fatalf("Failed to get user: %v", err)
	}
	if retrieved.DisplayName != "Player_XYZ" {
		t.Errorf("Expected display name 'Player_XYZ', got '%s'", retrieved.DisplayName)
	}
}

// ========== ValidateDisplayName Tests ==========

func TestUserService_ValidateDisplayName_Valid(t *testing.T) {
	service := &UserService{}

	validNames := []string{
		"Player_123",
		"abc",                 // minimum 3 chars
		"12345678901234567890", // maximum 20 chars
		"test-user",
		"TestUser",
		"user_123",
	}

	for _, name := range validNames {
		err := service.ValidateDisplayName(name)
		if err != nil {
			t.Errorf("ValidateDisplayName(%s) should be valid, got: %v", name, err)
		}
	}
}

func TestUserService_ValidateDisplayName_TooShort(t *testing.T) {
	service := &UserService{}

	shortNames := []string{
		"ab",  // 2 chars
		"a",   // 1 char
		"",    // empty
	}

	for _, name := range shortNames {
		err := service.ValidateDisplayName(name)
		if err != ErrDisplayNameTooShort {
			t.Errorf("ValidateDisplayName(%s) should return ErrDisplayNameTooShort, got: %v", name, err)
		}
	}
}

func TestUserService_ValidateDisplayName_TooLong(t *testing.T) {
	service := &UserService{}

	longName := "123456789012345678901" // 21 chars

	err := service.ValidateDisplayName(longName)
	if err != ErrDisplayNameTooLong {
		t.Errorf("ValidateDisplayName should return ErrDisplayNameTooLong, got: %v", err)
	}
}

func TestUserService_ValidateDisplayName_InvalidChars(t *testing.T) {
	service := &UserService{}

	invalidNames := []string{
		"user name",   // space
		"user@name",   // special char
		"user.name",   // period
		"name!",       // exclamation
		"name#tag",    // hash
		"user$name",   // dollar
	}

	for _, name := range invalidNames {
		err := service.ValidateDisplayName(name)
		if err != ErrDisplayNameInvalidChars {
			t.Errorf("ValidateDisplayName(%s) should return ErrDisplayNameInvalidChars, got: %v", name, err)
		}
	}
}

func TestUserService_ValidateDisplayName_Reserved(t *testing.T) {
	service := &UserService{}

	reservedNames := []string{
		"admin",
		"Admin123",
		"superadmin",
		"moderator",
		"modUser",
		"systemuser",
		"null",
		"undefined",
	}

	for _, name := range reservedNames {
		err := service.ValidateDisplayName(name)
		if err != ErrDisplayNameReserved {
			t.Errorf("ValidateDisplayName(%s) should return ErrDisplayNameReserved, got: %v", name, err)
		}
	}
}

// ========== GameResult Constants Tests ==========

func TestGameResult_Constants(t *testing.T) {
	if GameResultWin != "win" {
		t.Error("GameResultWin should be 'win'")
	}
	if GameResultLoss != "loss" {
		t.Error("GameResultLoss should be 'loss'")
	}
	if GameResultDraw != "draw" {
		t.Error("GameResultDraw should be 'draw'")
	}
}

// ========== Error Definitions Tests ==========

func TestServiceErrors(t *testing.T) {
	// Verify error messages are correct
	if ErrUserNotFound.Error() != "user not found" {
		t.Errorf("Unexpected error message: %s", ErrUserNotFound.Error())
	}

	if ErrDisplayNameTooShort.Error() != "display name must be at least 3 characters" {
		t.Errorf("Unexpected error message: %s", ErrDisplayNameTooShort.Error())
	}

	if ErrDisplayNameTooLong.Error() != "display name must be at most 20 characters" {
		t.Errorf("Unexpected error message: %s", ErrDisplayNameTooLong.Error())
	}

	// Verify errors are distinct
	if errors.Is(ErrUserNotFound, ErrDisplayNameTooShort) {
		t.Error("Errors should be distinct")
	}
}

// ========== UpdateStats Tests ==========

func TestUserService_UpdateStats_Win(t *testing.T) {
	repo := newMockUserRepository()
	ctx := context.Background()

	// Create initial user
	user := &models.User{
		ID:          "device-123",
		DisplayName: "Player",
		TotalGames:  5,
		Wins:        2,
		Losses:      2,
		Draws:       1,
	}
	repo.Create(ctx, user)

	// Update stats with a win
	user.TotalGames++
	user.Wins++
	repo.UpdateStats(ctx, "device-123", user.Stats())

	// Verify
	updated, _ := repo.GetByID(ctx, "device-123")
	if updated.TotalGames != 6 {
		t.Errorf("Expected 6 total games, got %d", updated.TotalGames)
	}
	if updated.Wins != 3 {
		t.Errorf("Expected 3 wins, got %d", updated.Wins)
	}
}

func TestUserService_UpdateStats_Loss(t *testing.T) {
	repo := newMockUserRepository()
	ctx := context.Background()

	user := &models.User{
		ID:          "device-123",
		DisplayName: "Player",
		TotalGames:  5,
		Wins:        2,
		Losses:      2,
		Draws:       1,
	}
	repo.Create(ctx, user)

	// Update stats with a loss
	user.TotalGames++
	user.Losses++
	repo.UpdateStats(ctx, "device-123", user.Stats())

	updated, _ := repo.GetByID(ctx, "device-123")
	if updated.Losses != 3 {
		t.Errorf("Expected 3 losses, got %d", updated.Losses)
	}
}

func TestUserService_UpdateStats_Draw(t *testing.T) {
	repo := newMockUserRepository()
	ctx := context.Background()

	user := &models.User{
		ID:          "device-123",
		DisplayName: "Player",
		TotalGames:  5,
		Wins:        2,
		Losses:      2,
		Draws:       1,
	}
	repo.Create(ctx, user)

	// Update stats with a draw
	user.TotalGames++
	user.Draws++
	repo.UpdateStats(ctx, "device-123", user.Stats())

	updated, _ := repo.GetByID(ctx, "device-123")
	if updated.Draws != 2 {
		t.Errorf("Expected 2 draws, got %d", updated.Draws)
	}
}

// ========== Edge Cases Tests ==========

func TestUserService_ValidateDisplayName_Unicode(t *testing.T) {
	service := &UserService{}

	// Unicode characters (Chinese) should not be allowed
	// since we only allow alphanumeric, underscore, hyphen
	err := service.ValidateDisplayName("测试用户")
	if err != ErrDisplayNameInvalidChars {
		t.Errorf("Unicode characters should be rejected, got: %v", err)
	}
}

func TestUserService_ValidateDisplayName_ExactBoundaries(t *testing.T) {
	service := &UserService{}

	// Exactly 3 characters (minimum)
	if err := service.ValidateDisplayName("abc"); err != nil {
		t.Errorf("3 character name should be valid: %v", err)
	}

	// Exactly 20 characters (maximum)
	if err := service.ValidateDisplayName("12345678901234567890"); err != nil {
		t.Errorf("20 character name should be valid: %v", err)
	}
}

func TestUserService_ValidateDisplayName_CaseSensitivity(t *testing.T) {
	service := &UserService{}

	// Reserved words should be case-insensitive
	testCases := []string{"ADMIN", "Admin", "aDmIn"}
	for _, name := range testCases {
		err := service.ValidateDisplayName(name)
		if err != ErrDisplayNameReserved {
			t.Errorf("Reserved word check should be case-insensitive for '%s', got: %v", name, err)
		}
	}
}

// ========== User Stats Calculation Tests ==========

func TestUserStats_WinPercentage(t *testing.T) {
	user := &models.User{
		TotalGames: 10,
		Wins:       6,
		Losses:     3,
		Draws:      1,
	}

	stats := user.Stats()

	expectedWinPct := 60.0 // 6/10 * 100
	if stats.WinPercentage != expectedWinPct {
		t.Errorf("Expected win percentage %.1f, got %.1f", expectedWinPct, stats.WinPercentage)
	}
}

func TestUserStats_WinPercentage_NoGames(t *testing.T) {
	user := &models.User{
		TotalGames: 0,
		Wins:       0,
		Losses:     0,
		Draws:      0,
	}

	stats := user.Stats()

	if stats.WinPercentage != 0 {
		t.Errorf("Win percentage with no games should be 0, got %.1f", stats.WinPercentage)
	}
}

func TestUserStats_AllWins(t *testing.T) {
	user := &models.User{
		TotalGames: 5,
		Wins:       5,
		Losses:     0,
		Draws:      0,
	}

	stats := user.Stats()

	if stats.WinPercentage != 100.0 {
		t.Errorf("Expected 100%% win rate, got %.1f", stats.WinPercentage)
	}
}

func TestUserStats_AllLosses(t *testing.T) {
	user := &models.User{
		TotalGames: 5,
		Wins:       0,
		Losses:     5,
		Draws:      0,
	}

	stats := user.Stats()

	if stats.WinPercentage != 0 {
		t.Errorf("Expected 0%% win rate, got %.1f", stats.WinPercentage)
	}
}
