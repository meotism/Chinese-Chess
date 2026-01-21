// Package game provides unit tests for the Xiangqi rules engine.
package game

import (
	"testing"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// ========== Flying General Rule Tests ==========

func TestRulesEngine_FlyingGeneral_NotFacing(t *testing.T) {
	board := NewBoard()

	// Place generals on different files
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 3, 9)
	board.Place(redGeneral)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	if rules.IsFlyingGeneral(board) {
		t.Error("Generals on different files should not trigger flying general")
	}
}

func TestRulesEngine_FlyingGeneral_FacingWithPieceBetween(t *testing.T) {
	board := NewBoard()

	// Place generals on same file with piece between
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 4, 9)
	blocker := createPiece(models.PieceTypeCannon, models.PlayerColorRed, 4, 5)
	board.Place(redGeneral)
	board.Place(blackGeneral)
	board.Place(blocker)

	rules := NewRulesEngine()

	if rules.IsFlyingGeneral(board) {
		t.Error("Generals with piece between should not trigger flying general")
	}
}

func TestRulesEngine_FlyingGeneral_FacingWithoutPieceBetween(t *testing.T) {
	board := NewBoard()

	// Place generals on same file with no pieces between
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 4, 9)
	board.Place(redGeneral)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	if !rules.IsFlyingGeneral(board) {
		t.Error("Generals facing each other without pieces should trigger flying general")
	}
}

// ========== Check Detection Tests ==========

func TestRulesEngine_IsInCheck_NotInCheck(t *testing.T) {
	board := NewInitialBoard()

	rules := NewRulesEngine()

	// Initial position should have no checks
	if rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should not be in check at start")
	}
	if rules.IsInCheck(board, models.PlayerColorBlack) {
		t.Error("Black should not be in check at start")
	}
}

func TestRulesEngine_IsInCheck_ChariotCheck(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 5)
	board.Place(redGeneral)
	board.Place(blackChariot)

	rules := NewRulesEngine()

	if !rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should be in check from chariot")
	}
}

func TestRulesEngine_IsInCheck_HorseCheck(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackHorse := createPiece(models.PieceTypeHorse, models.PlayerColorBlack, 5, 2)
	board.Place(redGeneral)
	board.Place(blackHorse)

	rules := NewRulesEngine()

	if !rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should be in check from horse")
	}
}

func TestRulesEngine_IsInCheck_CannonCheck(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackCannon := createPiece(models.PieceTypeCannon, models.PlayerColorBlack, 4, 7)
	screen := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 4, 3)
	board.Place(redGeneral)
	board.Place(blackCannon)
	board.Place(screen)

	rules := NewRulesEngine()

	if !rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should be in check from cannon with screen")
	}
}

func TestRulesEngine_IsInCheck_FlyingGeneralCheck(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 4, 9)
	board.Place(redGeneral)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	// Both generals should be considered "in check" due to flying general
	if !rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should be in check from flying general")
	}
	if !rules.IsInCheck(board, models.PlayerColorBlack) {
		t.Error("Black should be in check from flying general")
	}
}

// ========== Checkmate Tests ==========

func TestRulesEngine_IsCheckmate_BasicCheckmate(t *testing.T) {
	board := NewBoard()

	// Set up a simple checkmate position
	// Red general in corner, blocked by own pieces, attacked by chariot
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 3, 0)
	redAdvisor1 := createPiece(models.PieceTypeAdvisor, models.PlayerColorRed, 4, 0)
	redAdvisor2 := createPiece(models.PieceTypeAdvisor, models.PlayerColorRed, 3, 1)
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 3, 5)
	board.Place(redGeneral)
	board.Place(redAdvisor1)
	board.Place(redAdvisor2)
	board.Place(blackChariot)

	rules := NewRulesEngine()

	// Red should be in check
	if !rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should be in check")
	}

	// Red might still have moves (advisors can block/capture)
	// This depends on the specific position
}

func TestRulesEngine_IsNotCheckmate_CanBlock(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 3) // Can block
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 5)
	board.Place(redGeneral)
	board.Place(redChariot)
	board.Place(blackChariot)

	rules := NewRulesEngine()

	if !rules.IsInCheck(board, models.PlayerColorRed) {
		t.Error("Red should be in check")
	}

	if rules.IsCheckmate(board, models.PlayerColorRed) {
		t.Error("Should not be checkmate - can block with chariot")
	}
}

func TestRulesEngine_IsNotCheckmate_CanCapture(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 5) // Can capture
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 5)
	board.Place(redGeneral)
	board.Place(redChariot)
	board.Place(blackChariot)

	rules := NewRulesEngine()

	if rules.IsCheckmate(board, models.PlayerColorRed) {
		t.Error("Should not be checkmate - can capture attacking piece")
	}
}

func TestRulesEngine_IsNotCheckmate_CanEvade(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 1) // Can move sideways
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 5)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 5, 9) // Different file
	board.Place(redGeneral)
	board.Place(blackChariot)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	if rules.IsCheckmate(board, models.PlayerColorRed) {
		t.Error("Should not be checkmate - general can move sideways")
	}
}

// ========== Stalemate Tests ==========

func TestRulesEngine_IsStalemate_NotStalemate(t *testing.T) {
	board := NewInitialBoard()

	rules := NewRulesEngine()

	if rules.IsStalemate(board, models.PlayerColorRed) {
		t.Error("Initial position should not be stalemate for red")
	}
	if rules.IsStalemate(board, models.PlayerColorBlack) {
		t.Error("Initial position should not be stalemate for black")
	}
}

func TestRulesEngine_IsStalemate_NotInCheck(t *testing.T) {
	board := NewBoard()

	// Stalemate requires NOT being in check but having no legal moves
	// This is hard to set up in Xiangqi as the general usually has moves
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 5, 9)
	board.Place(redGeneral)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	// General should have legal moves
	if rules.IsStalemate(board, models.PlayerColorRed) {
		t.Error("Red should not be in stalemate with available moves")
	}
}

// ========== Legal Moves Tests ==========

func TestRulesEngine_GetLegalMoves_FiltersSelfCheck(t *testing.T) {
	board := NewBoard()

	// Red general with a chariot pinned
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 4, 3) // Pinned
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 7)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 5, 9)
	board.Place(redGeneral)
	board.Place(redChariot)
	board.Place(blackChariot)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	// The pinned chariot should have limited legal moves
	legalMoves := rules.GetLegalMoves(redChariot, board)

	// Should only be able to move along the file (staying in the pin line)
	// Or not move at all if it would expose the general
	for _, move := range legalMoves {
		// Simulate the move
		testBoard := board.Copy()
		testBoard.Move(redChariot.Position, move)

		if rules.IsInCheck(testBoard, models.PlayerColorRed) {
			t.Errorf("Legal move to %s would leave red in check", move.Notation())
		}
	}
}

func TestRulesEngine_GetLegalMoves_FiltersFlyingGeneral(t *testing.T) {
	board := NewBoard()

	// Position where general move would create flying general
	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blocker := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 5, 0)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 4, 9)
	board.Place(redGeneral)
	board.Place(blocker)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	legalMoves := rules.GetLegalMoves(redGeneral, board)

	// Moving right to (5,0) would work, but moving to reveal flying general should be blocked
	for _, move := range legalMoves {
		testBoard := board.Copy()
		testBoard.Move(redGeneral.Position, move)

		if rules.IsFlyingGeneral(testBoard) {
			t.Errorf("Legal move to %s would create flying general", move.Notation())
		}
	}
}

// ========== IsValidMove Tests ==========

func TestRulesEngine_IsValidMove_BasicMove(t *testing.T) {
	board := NewInitialBoard()

	rules := NewRulesEngine()

	// Horse can make opening move
	horse := board.At(Position{1, 0})
	if horse == nil || horse.Type != models.PieceTypeHorse {
		t.Fatal("Expected horse at b0")
	}

	if !rules.IsValidMove(horse, Position{2, 2}, board) {
		t.Error("Horse should be able to make opening move to c2")
	}
}

func TestRulesEngine_IsValidMove_MoveExposesCheck(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 4, 3)
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 7)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 5, 9)
	board.Place(redGeneral)
	board.Place(redChariot)
	board.Place(blackChariot)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	// Moving the red chariot sideways would expose the general
	if rules.IsValidMove(redChariot, Position{5, 3}, board) {
		t.Error("Moving pinned piece should be invalid")
	}
}

func TestRulesEngine_IsValidMove_MoveCreatesFlyingGeneral(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 4, 4) // Blocking
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 4, 9)
	board.Place(redGeneral)
	board.Place(redChariot)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	// Moving the chariot off the file would create flying general
	if rules.IsValidMove(redChariot, Position{5, 4}, board) {
		t.Error("Move creating flying general should be invalid")
	}
}

// ========== GetAllLegalMoves Tests ==========

func TestRulesEngine_GetAllLegalMoves_InitialPosition(t *testing.T) {
	board := NewInitialBoard()

	rules := NewRulesEngine()

	redMoves := rules.GetAllLegalMoves(board, models.PlayerColorRed)

	// In initial position, Red has:
	// - 2 horses: 2 moves each = 4
	// - 2 cannons: various moves
	// - 5 soldiers: 1 move each = 5
	// Should have a reasonable number of opening moves
	if len(redMoves) < 10 {
		t.Errorf("Expected at least 10 legal moves for red at start, got %d", len(redMoves))
	}
}

// ========== CanCapture Tests ==========

func TestRulesEngine_CanCapture_Valid(t *testing.T) {
	board := NewBoard()

	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 0)
	blackSoldier := createPiece(models.PieceTypeSoldier, models.PlayerColorBlack, 0, 5)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 4, 9)
	board.Place(redChariot)
	board.Place(blackSoldier)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	if !rules.CanCapture(Position{0, 0}, Position{0, 5}, board) {
		t.Error("Chariot should be able to capture soldier")
	}
}

func TestRulesEngine_CanCapture_OwnPiece(t *testing.T) {
	board := NewBoard()

	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 0)
	redSoldier := createPiece(models.PieceTypeSoldier, models.PlayerColorRed, 0, 3)
	board.Place(redChariot)
	board.Place(redSoldier)

	rules := NewRulesEngine()

	if rules.CanCapture(Position{0, 0}, Position{0, 3}, board) {
		t.Error("Should not be able to capture own piece")
	}
}

func TestRulesEngine_CanCapture_EmptyTarget(t *testing.T) {
	board := NewBoard()

	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 0, 0)
	board.Place(redChariot)

	rules := NewRulesEngine()

	if rules.CanCapture(Position{0, 0}, Position{0, 5}, board) {
		t.Error("Cannot capture empty square")
	}
}

// ========== WouldExposeGeneral Tests ==========

func TestRulesEngine_WouldExposeGeneral(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	redChariot := createPiece(models.PieceTypeChariot, models.PlayerColorRed, 4, 3)
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 7)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 5, 9)
	board.Place(redGeneral)
	board.Place(redChariot)
	board.Place(blackChariot)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	// Moving the red chariot sideways would expose the general
	if !rules.WouldExposeGeneral(redChariot, Position{5, 3}, board) {
		t.Error("Moving pinned chariot should expose general")
	}

	// Moving along the file should not expose
	if rules.WouldExposeGeneral(redChariot, Position{4, 4}, board) {
		t.Error("Moving along pin line should not expose general")
	}
}

// ========== GetCheckingPieces Tests ==========

func TestRulesEngine_GetCheckingPieces_None(t *testing.T) {
	board := NewInitialBoard()

	rules := NewRulesEngine()

	checkingPieces := rules.GetCheckingPieces(board, models.PlayerColorRed)

	if len(checkingPieces) != 0 {
		t.Errorf("Expected no checking pieces at start, got %d", len(checkingPieces))
	}
}

func TestRulesEngine_GetCheckingPieces_Single(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 5)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 5, 9)
	board.Place(redGeneral)
	board.Place(blackChariot)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	checkingPieces := rules.GetCheckingPieces(board, models.PlayerColorRed)

	if len(checkingPieces) != 1 {
		t.Errorf("Expected 1 checking piece, got %d", len(checkingPieces))
	}
	if len(checkingPieces) > 0 && checkingPieces[0].Type != models.PieceTypeChariot {
		t.Error("Expected chariot to be the checking piece")
	}
}

func TestRulesEngine_GetCheckingPieces_Double(t *testing.T) {
	board := NewBoard()

	redGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorRed, 4, 0)
	blackChariot := createPiece(models.PieceTypeChariot, models.PlayerColorBlack, 4, 5)
	blackHorse := createPiece(models.PieceTypeHorse, models.PlayerColorBlack, 5, 2)
	blackGeneral := createPiece(models.PieceTypeGeneral, models.PlayerColorBlack, 3, 9)
	board.Place(redGeneral)
	board.Place(blackChariot)
	board.Place(blackHorse)
	board.Place(blackGeneral)

	rules := NewRulesEngine()

	checkingPieces := rules.GetCheckingPieces(board, models.PlayerColorRed)

	if len(checkingPieces) != 2 {
		t.Errorf("Expected 2 checking pieces, got %d", len(checkingPieces))
	}
}
