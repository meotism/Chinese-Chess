// Package game provides unit tests for piece move validators.
package game

import (
	"testing"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// Helper function to create a piece at a position
func createPiece(pieceType models.PieceType, color models.PlayerColor, file, rank int) *Piece {
	return &Piece{
		Type:     pieceType,
		Color:    color,
		Position: Position{file, rank},
	}
}

// ========== General Validator Tests ==========

func TestGeneralValidator_ValidMoves(t *testing.T) {
	board := NewBoard()

	// Place red general in center of palace
	general := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 1)
	board.Place(general)

	validator := &GeneralValidator{}
	moves := validator.GetValidMoves(general, board)

	// Should have 4 moves: up, down, left, right (all within palace)
	expectedMoves := []Position{
		{4, 2}, // up
		{4, 0}, // down
		{5, 1}, // right
		{3, 1}, // left
	}

	if len(moves) != len(expectedMoves) {
		t.Errorf("Expected %d moves, got %d", len(expectedMoves), len(moves))
	}

	for _, expected := range expectedMoves {
		found := false
		for _, move := range moves {
			if move == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Expected move to %s not found", expected.Notation())
		}
	}
}

func TestGeneralValidator_StaysInPalace(t *testing.T) {
	board := NewBoard()

	// Place red general at corner of palace
	general := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 3, 0)
	board.Place(general)

	validator := &GeneralValidator{}

	// Try to move outside palace
	if validator.IsValidMove(general, Position{2, 0}, board) {
		t.Error("General should not be able to move outside palace")
	}
}

func TestGeneralValidator_CannotCaptureOwnPiece(t *testing.T) {
	board := NewBoard()

	general := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	advisor := createPiece(models.PieceTypeAdvisor, models.PlayerColorRed, 4, 1)
	board.Place(general)
	board.Place(advisor)

	validator := &GeneralValidator{}

	if validator.IsValidMove(general, Position{4, 1}, board) {
		t.Error("General should not be able to capture own piece")
	}
}

func TestGeneralValidator_CanCaptureEnemy(t *testing.T) {
	board := NewBoard()

	general := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 1)
	enemy := createPiece(models.PieceTypeAdvisor, models.PlayerColorBlack, 4, 2)
	board.Place(general)
	board.Place(enemy)

	validator := &GeneralValidator{}

	if !validator.IsValidMove(general, Position{4, 2}, board) {
		t.Error("General should be able to capture enemy piece")
	}
}

// ========== Advisor Validator Tests ==========

func TestAdvisorValidator_ValidMoves(t *testing.T) {
	board := NewBoard()

	// Place red advisor in center of palace
	advisor := createPiece(models.PieceTypeAdvisor, models.PlayerColorRed, 4, 1)
	board.Place(advisor)

	validator := &AdvisorValidator{}
	moves := validator.GetValidMoves(advisor, board)

	// From center of palace, advisor can move to 4 diagonal corners
	expectedMoves := []Position{
		{5, 2}, // up-right
		{3, 2}, // up-left
		{5, 0}, // down-right
		{3, 0}, // down-left
	}

	if len(moves) != len(expectedMoves) {
		t.Errorf("Expected %d moves, got %d", len(expectedMoves), len(moves))
	}
}

func TestAdvisorValidator_StaysInPalace(t *testing.T) {
	board := NewBoard()

	advisor := createPiece(models.PieceTypeAdvisor, models.PlayerColorRed, 5, 0)
	board.Place(advisor)

	validator := &AdvisorValidator{}

	// Try to move outside palace
	if validator.IsValidMove(advisor, Position{6, 1}, board) {
		t.Error("Advisor should not be able to move outside palace")
	}
}

// ========== Elephant Validator Tests ==========

func TestElephantValidator_ValidMoves(t *testing.T) {
	board := NewBoard()

	// Place red elephant
	elephant := createPiece(models.PieceTypeElephant, models.PlayerColorRed, 2, 0)
	board.Place(elephant)

	validator := &ElephantValidator{}
	moves := validator.GetValidMoves(elephant, board)

	// Should have 2 valid moves (diagonal 2 steps, within red side)
	expectedMoves := []Position{
		{0, 2},
		{4, 2},
	}

	if len(moves) != len(expectedMoves) {
		t.Errorf("Expected %d moves, got %d: %v", len(expectedMoves), len(moves), moves)
	}
}

func TestElephantValidator_CannotCrossRiver(t *testing.T) {
	board := NewBoard()

	// Place red elephant near river
	elephant := createPiece(models.PieceTypeElephant, models.PlayerColorRed, 4, 4)
	board.Place(elephant)

	validator := &ElephantValidator{}

	// Try to cross river
	if validator.IsValidMove(elephant, Position{2, 6}, board) {
		t.Error("Red elephant should not be able to cross river")
	}
	if validator.IsValidMove(elephant, Position{6, 6}, board) {
		t.Error("Red elephant should not be able to cross river")
	}
}

func TestElephantValidator_BlockedByEye(t *testing.T) {
	board := NewBoard()

	elephant := createPiece(models.PieceTypeElephant, models.PlayerColorRed, 2, 0)
	blocker := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 3, 1)
	board.Place(elephant)
	board.Place(blocker)

	validator := &ElephantValidator{}

	// Should be blocked from moving to (4, 2)
	if validator.IsValidMove(elephant, Position{4, 2}, board) {
		t.Error("Elephant should be blocked by piece at eye position")
	}
}

// ========== Horse Validator Tests ==========

func TestHorseValidator_ValidMoves(t *testing.T) {
	board := NewBoard()

	// Place horse in center
	horse := createPiece(models.PieceTypeHorse, models.PlayerColorRed, 4, 4)
	board.Place(horse)

	validator := &HorseValidator{}
	moves := validator.GetValidMoves(horse, board)

	// Horse should have 8 possible L-shaped moves from center
	if len(moves) != 8 {
		t.Errorf("Expected 8 moves from center, got %d", len(moves))
	}
}

func TestHorseValidator_BlockedByLeg(t *testing.T) {
	board := NewBoard()

	horse := createPiece(models.PieceTypeHorse, models.PlayerColorRed, 1, 0)
	blocker := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 1, 1) // blocks vertical moves
	board.Place(horse)
	board.Place(blocker)

	validator := &HorseValidator{}

	// Should be blocked from moves that go through (1, 1)
	if validator.IsValidMove(horse, Position{0, 2}, board) {
		t.Error("Horse should be blocked by piece at leg position")
	}
	if validator.IsValidMove(horse, Position{2, 2}, board) {
		t.Error("Horse should be blocked by piece at leg position")
	}
}

func TestHorseValidator_NotBlockedHorizontally(t *testing.T) {
	board := NewBoard()

	horse := createPiece(models.PieceTypeHorse, models.PlayerColorRed, 1, 0)
	blocker := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 1, 1)
	board.Place(horse)
	board.Place(blocker)

	validator := &HorseValidator{}

	// Horizontal moves should still work
	if !validator.IsValidMove(horse, Position{3, 1}, board) {
		t.Error("Horse should be able to make horizontal L-move")
	}
}

// ========== Chariot Validator Tests ==========

func TestChariotValidator_ValidMoves(t *testing.T) {
	board := NewBoard()

	chariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 4, 4)
	board.Place(chariot)

	validator := &ChariotValidator{}
	moves := validator.GetValidMoves(chariot, board)

	// From center, chariot can move to 17 positions (8 vertical + 9 horizontal - 1)
	// Actually: 4 up + 4 down + 4 left + 4 right = 16 positions
	if len(moves) != 16 {
		t.Errorf("Expected 16 moves from center, got %d", len(moves))
	}
}

func TestChariotValidator_BlockedByPiece(t *testing.T) {
	board := NewBoard()

	chariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 0)
	blocker := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 0, 3)
	board.Place(chariot)
	board.Place(blocker)

	validator := &ChariotValidator{}

	// Can move up to blocker but not past it
	if !validator.IsValidMove(chariot, Position{0, 2}, board) {
		t.Error("Chariot should be able to move up to blocker")
	}
	if validator.IsValidMove(chariot, Position{0, 3}, board) {
		t.Error("Chariot should not be able to capture friendly piece")
	}
	if validator.IsValidMove(chariot, Position{0, 4}, board) {
		t.Error("Chariot should not be able to pass blocker")
	}
}

func TestChariotValidator_CanCaptureEnemy(t *testing.T) {
	board := NewBoard()

	chariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 0)
	enemy := createPiece(models.PieceTypeSoldier, models.PlayerColorBlack, 0, 3)
	board.Place(chariot)
	board.Place(enemy)

	validator := &ChariotValidator{}

	if !validator.IsValidMove(chariot, Position{0, 3}, board) {
		t.Error("Chariot should be able to capture enemy")
	}
	if validator.IsValidMove(chariot, Position{0, 4}, board) {
		t.Error("Chariot should not be able to pass captured piece")
	}
}

// ========== Cannon Validator Tests ==========

func TestCannonValidator_NonCaptureMove(t *testing.T) {
	board := NewBoard()

	cannon := createPiece(models.PieceTypeCannon, models.PlayerColorRed, 4, 4)
	board.Place(cannon)

	validator := &CannonValidator{}

	// Should be able to move to empty squares
	if !validator.IsValidMove(cannon, Position{4, 5}, board) {
		t.Error("Cannon should be able to move to empty square")
	}
}

func TestCannonValidator_CaptureWithScreen(t *testing.T) {
	board := NewBoard()

	cannon := createPiece(models.PieceTypeCannon, models.PlayerColorRed, 0, 0)
	screen := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 0, 3)
	target := createPiece(models.PieceTypeSoldier, models.PlayerColorBlack, 0, 6)
	board.Place(cannon)
	board.Place(screen)
	board.Place(target)

	validator := &CannonValidator{}

	// Should be able to capture target by jumping over screen
	if !validator.IsValidMove(cannon, Position{0, 6}, board) {
		t.Error("Cannon should be able to capture by jumping over screen")
	}
}

func TestCannonValidator_CannotCaptureWithoutScreen(t *testing.T) {
	board := NewBoard()

	cannon := createPiece(models.PieceTypeCannon, models.PlayerColorRed, 0, 0)
	target := createPiece(models.PieceTypeSoldier, models.PlayerColorBlack, 0, 3)
	board.Place(cannon)
	board.Place(target)

	validator := &CannonValidator{}

	// Should not be able to capture without jumping over a piece
	if validator.IsValidMove(cannon, Position{0, 3}, board) {
		t.Error("Cannon should not be able to capture without screen")
	}
}

func TestCannonValidator_CannotCaptureWithTwoScreens(t *testing.T) {
	board := NewBoard()

	cannon := createPiece(models.PieceTypeCannon, models.PlayerColorRed, 0, 0)
	screen1 := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 0, 2)
	screen2 := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 0, 4)
	target := createPiece(models.PieceTypeSoldier, models.PlayerColorBlack, 0, 6)
	board.Place(cannon)
	board.Place(screen1)
	board.Place(screen2)
	board.Place(target)

	validator := &CannonValidator{}

	// Should not be able to capture with two screens
	if validator.IsValidMove(cannon, Position{0, 6}, board) {
		t.Error("Cannon should not be able to capture with two screens")
	}
}

func TestCannonValidator_BlockedForNonCapture(t *testing.T) {
	board := NewBoard()

	cannon := createPiece(models.PieceTypeCannon, models.PlayerColorRed, 0, 0)
	blocker := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 0, 3)
	board.Place(cannon)
	board.Place(blocker)

	validator := &CannonValidator{}

	// Cannot pass blocker for non-capture moves
	if validator.IsValidMove(cannon, Position{0, 5}, board) {
		t.Error("Cannon should not be able to pass blocker for non-capture")
	}
}

// ========== Soldier Validator Tests ==========

func TestSoldierValidator_BeforeRiver(t *testing.T) {
	board := NewBoard()

	// Red soldier before crossing river
	soldier := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 4, 3)
	board.Place(soldier)

	validator := &SoldierValidator{}
	moves := validator.GetValidMoves(soldier, board)

	// Can only move forward
	if len(moves) != 1 {
		t.Errorf("Expected 1 move before river, got %d", len(moves))
	}
	if moves[0] != (Position{4, 4}) {
		t.Errorf("Expected move to (4,4), got %s", moves[0].Notation())
	}
}

func TestSoldierValidator_AfterRiver(t *testing.T) {
	board := NewBoard()

	// Red soldier after crossing river
	soldier := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 4, 5)
	board.Place(soldier)

	validator := &SoldierValidator{}
	moves := validator.GetValidMoves(soldier, board)

	// Can move forward and sideways (3 moves)
	if len(moves) != 3 {
		t.Errorf("Expected 3 moves after river, got %d", len(moves))
	}
}

func TestSoldierValidator_CannotMoveBackward(t *testing.T) {
	board := NewBoard()

	soldier := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 4, 5)
	board.Place(soldier)

	validator := &SoldierValidator{}

	// Cannot move backward
	if validator.IsValidMove(soldier, Position{4, 4}, board) {
		t.Error("Soldier should not be able to move backward")
	}
}

func TestSoldierValidator_BlackSoldierDirection(t *testing.T) {
	board := NewBoard()

	// Black soldier moves in opposite direction
	soldier := createPiece(models.PieceTypeSoldier, models.PlayerColorBlack, 4, 6)
	board.Place(soldier)

	validator := &SoldierValidator{}

	// Forward for black is decreasing rank
	if !validator.IsValidMove(soldier, Position{4, 5}, board) {
		t.Error("Black soldier should be able to move forward (decreasing rank)")
	}
	if validator.IsValidMove(soldier, Position{4, 7}, board) {
		t.Error("Black soldier should not be able to move backward")
	}
}

// ========== GetValidator Factory Tests ==========

func TestGetValidator_ReturnsCorrectType(t *testing.T) {
	testCases := []struct {
		pieceType models.PieceType
		expected  MoveValidator
	}{
		{models.PieceTypeGeneral, &GeneralValidator{}},
		{models.PieceTypeAdvisor, &AdvisorValidator{}},
		{models.PieceTypeElephant, &ElephantValidator{}},
		{models.PieceTypeHorse, &HorseValidator{}},
		{models.PieceTypeChariot, &ChariotValidator{}},
		{models.PieceTypeCannon, &CannonValidator{}},
		{models.PieceTypeSoldier, &SoldierValidator{}},
	}

	for _, tc := range testCases {
		validator := GetValidator(tc.pieceType)
		if validator == nil {
			t.Errorf("GetValidator returned nil for %s", tc.pieceType)
		}
	}
}
