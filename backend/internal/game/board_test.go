// Package game provides unit tests for the Xiangqi board implementation.
package game

import (
	"testing"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// TestNewBoard tests the creation of an empty board.
func TestNewBoard(t *testing.T) {
	board := NewBoard()

	if board == nil {
		t.Fatal("NewBoard returned nil")
	}

	// Verify all squares are empty
	for rank := 0; rank < RankCount; rank++ {
		for file := 0; file < FileCount; file++ {
			if board.squares[rank][file] != nil {
				t.Errorf("Expected empty square at (%d, %d), got piece", file, rank)
			}
		}
	}
}

// TestNewInitialBoard tests the standard starting position.
func TestNewInitialBoard(t *testing.T) {
	board := NewInitialBoard()

	if board == nil {
		t.Fatal("NewInitialBoard returned nil")
	}

	// Verify Red back row
	testCases := []struct {
		pos   Position
		pType models.PieceType
		color models.PlayerColor
	}{
		// Red back row
		{Position{0, 0}, models.PieceTypeChariot, models.PlayerColorRed},
		{Position{1, 0}, models.PieceTypeHorse, models.PlayerColorRed},
		{Position{2, 0}, models.PieceTypeElephant, models.PlayerColorRed},
		{Position{3, 0}, models.PieceTypeAdvisor, models.PlayerColorRed},
		{Position{4, 0}, models.PieceTypeGeneral, models.PlayerColorRed},
		{Position{5, 0}, models.PieceTypeAdvisor, models.PlayerColorRed},
		{Position{6, 0}, models.PieceTypeElephant, models.PlayerColorRed},
		{Position{7, 0}, models.PieceTypeHorse, models.PlayerColorRed},
		{Position{8, 0}, models.PieceTypeChariot, models.PlayerColorRed},

		// Red cannons
		{Position{1, 2}, models.PieceTypeCannon, models.PlayerColorRed},
		{Position{7, 2}, models.PieceTypeCannon, models.PlayerColorRed},

		// Red soldiers
		{Position{0, 3}, models.PieceTypeSoldier, models.PlayerColorRed},
		{Position{2, 3}, models.PieceTypeSoldier, models.PlayerColorRed},
		{Position{4, 3}, models.PieceTypeSoldier, models.PlayerColorRed},
		{Position{6, 3}, models.PieceTypeSoldier, models.PlayerColorRed},
		{Position{8, 3}, models.PieceTypeSoldier, models.PlayerColorRed},

		// Black back row
		{Position{0, 9}, models.PieceTypeChariot, models.PlayerColorBlack},
		{Position{1, 9}, models.PieceTypeHorse, models.PlayerColorBlack},
		{Position{2, 9}, models.PieceTypeElephant, models.PlayerColorBlack},
		{Position{3, 9}, models.PieceTypeAdvisor, models.PlayerColorBlack},
		{Position{4, 9}, models.PieceTypeGeneral, models.PlayerColorBlack},
		{Position{5, 9}, models.PieceTypeAdvisor, models.PlayerColorBlack},
		{Position{6, 9}, models.PieceTypeElephant, models.PlayerColorBlack},
		{Position{7, 9}, models.PieceTypeHorse, models.PlayerColorBlack},
		{Position{8, 9}, models.PieceTypeChariot, models.PlayerColorBlack},

		// Black cannons
		{Position{1, 7}, models.PieceTypeCannon, models.PlayerColorBlack},
		{Position{7, 7}, models.PieceTypeCannon, models.PlayerColorBlack},

		// Black soldiers
		{Position{0, 6}, models.PieceTypeSoldier, models.PlayerColorBlack},
		{Position{2, 6}, models.PieceTypeSoldier, models.PlayerColorBlack},
		{Position{4, 6}, models.PieceTypeSoldier, models.PlayerColorBlack},
		{Position{6, 6}, models.PieceTypeSoldier, models.PlayerColorBlack},
		{Position{8, 6}, models.PieceTypeSoldier, models.PlayerColorBlack},
	}

	for _, tc := range testCases {
		piece := board.At(tc.pos)
		if piece == nil {
			t.Errorf("Expected %s at %s, got nil", tc.pType, tc.pos.Notation())
			continue
		}
		if piece.Type != tc.pType {
			t.Errorf("Expected %s at %s, got %s", tc.pType, tc.pos.Notation(), piece.Type)
		}
		if piece.Color != tc.color {
			t.Errorf("Expected %s at %s, got %s", tc.color, tc.pos.Notation(), piece.Color)
		}
	}

	// Count total pieces
	redPieces := board.GetPieces(models.PlayerColorRed)
	blackPieces := board.GetPieces(models.PlayerColorBlack)

	if len(redPieces) != 16 {
		t.Errorf("Expected 16 red pieces, got %d", len(redPieces))
	}
	if len(blackPieces) != 16 {
		t.Errorf("Expected 16 black pieces, got %d", len(blackPieces))
	}
}

// TestBoardPlace tests placing pieces on the board.
func TestBoardPlace(t *testing.T) {
	board := NewBoard()

	piece := &Piece{
		Type:     models.PieceTypeGeneral,
		Color:    models.PlayerColorRed,
		Position: Position{4, 0},
	}

	board.Place(piece)

	retrieved := board.At(Position{4, 0})
	if retrieved == nil {
		t.Fatal("Expected piece at e0, got nil")
	}
	if retrieved.Type != models.PieceTypeGeneral {
		t.Errorf("Expected general, got %s", retrieved.Type)
	}
}

// TestBoardRemove tests removing pieces from the board.
func TestBoardRemove(t *testing.T) {
	board := NewInitialBoard()

	pos := Position{4, 0} // Red general
	removed := board.Remove(pos)

	if removed == nil {
		t.Fatal("Expected removed piece, got nil")
	}
	if removed.Type != models.PieceTypeGeneral {
		t.Errorf("Expected general, got %s", removed.Type)
	}

	// Verify position is now empty
	if board.At(pos) != nil {
		t.Error("Position should be empty after removal")
	}
}

// TestBoardMove tests moving pieces on the board.
func TestBoardMove(t *testing.T) {
	board := NewInitialBoard()

	from := Position{1, 0} // Red horse
	to := Position{2, 2}   // Valid horse move

	captured := board.Move(from, to)

	// No capture expected
	if captured != nil {
		t.Errorf("Expected no capture, got %s", captured.Type)
	}

	// Verify source is empty
	if board.At(from) != nil {
		t.Error("Source position should be empty after move")
	}

	// Verify destination has the piece
	piece := board.At(to)
	if piece == nil {
		t.Fatal("Expected piece at destination, got nil")
	}
	if piece.Type != models.PieceTypeHorse {
		t.Errorf("Expected horse, got %s", piece.Type)
	}
	if piece.Position != to {
		t.Errorf("Piece position not updated, expected %s, got %s", to.Notation(), piece.Position.Notation())
	}
}

// TestBoardMoveCapture tests capturing a piece.
func TestBoardMoveCapture(t *testing.T) {
	board := NewBoard()

	// Place two pieces
	redChariot := &Piece{
		Type:     models.PieceTypeChariot,
		Color:    models.PlayerColorRed,
		Position: Position{0, 0},
	}
	blackChariot := &Piece{
		Type:     models.PieceTypeChariot,
		Color:    models.PlayerColorBlack,
		Position: Position{0, 5},
	}

	board.Place(redChariot)
	board.Place(blackChariot)

	captured := board.Move(Position{0, 0}, Position{0, 5})

	if captured == nil {
		t.Fatal("Expected captured piece")
	}
	if captured.Color != models.PlayerColorBlack {
		t.Error("Expected black piece to be captured")
	}
}

// TestBoardCopy tests deep copying the board.
func TestBoardCopy(t *testing.T) {
	board := NewInitialBoard()
	copy := board.Copy()

	// Verify copy has same pieces
	for rank := 0; rank < RankCount; rank++ {
		for file := 0; file < FileCount; file++ {
			pos := Position{file, rank}
			orig := board.At(pos)
			copied := copy.At(pos)

			if orig == nil && copied == nil {
				continue
			}
			if orig == nil || copied == nil {
				t.Errorf("Mismatch at %s: original=%v, copy=%v", pos.Notation(), orig, copied)
				continue
			}
			if orig.Type != copied.Type || orig.Color != copied.Color {
				t.Errorf("Piece mismatch at %s", pos.Notation())
			}
		}
	}

	// Verify modifying copy doesn't affect original
	copy.Remove(Position{4, 0})
	if board.At(Position{4, 0}) == nil {
		t.Error("Original board was modified when copy was changed")
	}
}

// TestBoardHasEnemy tests enemy detection.
func TestBoardHasEnemy(t *testing.T) {
	board := NewInitialBoard()

	// Red piece at red general position should not be enemy for red
	if board.HasEnemy(Position{4, 0}, models.PlayerColorRed) {
		t.Error("Red general should not be enemy for red")
	}

	// Red piece at red general position should be enemy for black
	if !board.HasEnemy(Position{4, 0}, models.PlayerColorBlack) {
		t.Error("Red general should be enemy for black")
	}
}

// TestBoardHasFriendly tests friendly detection.
func TestBoardHasFriendly(t *testing.T) {
	board := NewInitialBoard()

	if !board.HasFriendly(Position{4, 0}, models.PlayerColorRed) {
		t.Error("Red general should be friendly for red")
	}

	if board.HasFriendly(Position{4, 0}, models.PlayerColorBlack) {
		t.Error("Red general should not be friendly for black")
	}
}

// TestBoardGetGeneral tests finding the general.
func TestBoardGetGeneral(t *testing.T) {
	board := NewInitialBoard()

	redGeneral := board.GetGeneral(models.PlayerColorRed)
	if redGeneral == nil {
		t.Fatal("Red general not found")
	}
	if redGeneral.Position != (Position{4, 0}) {
		t.Errorf("Red general at wrong position: %s", redGeneral.Position.Notation())
	}

	blackGeneral := board.GetGeneral(models.PlayerColorBlack)
	if blackGeneral == nil {
		t.Fatal("Black general not found")
	}
	if blackGeneral.Position != (Position{4, 9}) {
		t.Errorf("Black general at wrong position: %s", blackGeneral.Position.Notation())
	}
}

// TestPositionIsValid tests position validity.
func TestPositionIsValid(t *testing.T) {
	testCases := []struct {
		pos   Position
		valid bool
	}{
		{Position{0, 0}, true},
		{Position{8, 9}, true},
		{Position{4, 5}, true},
		{Position{-1, 0}, false},
		{Position{0, -1}, false},
		{Position{9, 0}, false},
		{Position{0, 10}, false},
	}

	for _, tc := range testCases {
		if tc.pos.IsValid() != tc.valid {
			t.Errorf("Position %v validity: expected %v, got %v", tc.pos, tc.valid, !tc.valid)
		}
	}
}

// TestPositionIsInPalace tests palace boundary checks.
func TestPositionIsInPalace(t *testing.T) {
	redPalacePositions := []Position{
		{3, 0}, {4, 0}, {5, 0},
		{3, 1}, {4, 1}, {5, 1},
		{3, 2}, {4, 2}, {5, 2},
	}

	for _, pos := range redPalacePositions {
		if !pos.IsInRedPalace() {
			t.Errorf("Position %s should be in red palace", pos.Notation())
		}
		if !pos.IsInPalace(models.PlayerColorRed) {
			t.Errorf("Position %s should be in palace for red", pos.Notation())
		}
	}

	blackPalacePositions := []Position{
		{3, 7}, {4, 7}, {5, 7},
		{3, 8}, {4, 8}, {5, 8},
		{3, 9}, {4, 9}, {5, 9},
	}

	for _, pos := range blackPalacePositions {
		if !pos.IsInBlackPalace() {
			t.Errorf("Position %s should be in black palace", pos.Notation())
		}
		if !pos.IsInPalace(models.PlayerColorBlack) {
			t.Errorf("Position %s should be in palace for black", pos.Notation())
		}
	}

	// Outside palace
	outsidePalace := Position{0, 0}
	if outsidePalace.IsInRedPalace() {
		t.Errorf("Position %s should not be in red palace", outsidePalace.Notation())
	}
}

// TestPositionHasCrossedRiver tests river crossing detection.
func TestPositionHasCrossedRiver(t *testing.T) {
	// Red pieces crossing river (going to black side)
	blackSidePos := Position{4, 5}
	if !blackSidePos.HasCrossedRiver(models.PlayerColorRed) {
		t.Error("Position on black side should count as crossed for red")
	}

	redSidePos := Position{4, 4}
	if redSidePos.HasCrossedRiver(models.PlayerColorRed) {
		t.Error("Position on red side should not count as crossed for red")
	}

	// Black pieces crossing river (going to red side)
	if !redSidePos.HasCrossedRiver(models.PlayerColorBlack) {
		t.Error("Position on red side should count as crossed for black")
	}

	if blackSidePos.HasCrossedRiver(models.PlayerColorBlack) {
		t.Error("Position on black side should not count as crossed for black")
	}
}

// TestPositionNotation tests algebraic notation conversion.
func TestPositionNotation(t *testing.T) {
	testCases := []struct {
		pos      Position
		notation string
	}{
		{Position{0, 0}, "a0"},
		{Position{4, 0}, "e0"},
		{Position{8, 9}, "i9"},
		{Position{4, 5}, "e5"},
	}

	for _, tc := range testCases {
		if tc.pos.Notation() != tc.notation {
			t.Errorf("Position %v notation: expected %s, got %s", tc.pos, tc.notation, tc.pos.Notation())
		}
	}
}

// TestPositionOffset tests position offsetting.
func TestPositionOffset(t *testing.T) {
	pos := Position{4, 4}

	// Valid offset
	newPos := pos.Offset(1, 1)
	if newPos.File != 5 || newPos.Rank != 5 {
		t.Errorf("Expected (5,5), got (%d,%d)", newPos.File, newPos.Rank)
	}

	// Negative offset
	newPos = pos.Offset(-2, -2)
	if newPos.File != 2 || newPos.Rank != 2 {
		t.Errorf("Expected (2,2), got (%d,%d)", newPos.File, newPos.Rank)
	}
}
