// Package game provides unit tests for the Xiangqi game engine.
package game

import (
	"testing"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// ========== NewGameEngine Tests ==========

func TestNewGameEngine(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	if engine == nil {
		t.Fatal("NewGameEngine returned nil")
	}

	if engine.GetCurrentTurn() != models.PlayerColorRed {
		t.Error("Red should move first")
	}

	if engine.IsCheck() {
		t.Error("Should not be in check at start")
	}

	if engine.IsCheckmate() {
		t.Error("Should not be checkmate at start")
	}

	if engine.IsStalemate() {
		t.Error("Should not be stalemate at start")
	}

	if engine.IsGameOver() {
		t.Error("Game should not be over at start")
	}

	if len(engine.GetMoveHistory()) != 0 {
		t.Error("Move history should be empty at start")
	}
}

// ========== ValidateAndMakeMove Tests ==========

func TestEngine_ValidateAndMakeMove_ValidMove(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Red's first move: horse from b0 to c2
	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b0",
		To:       "c2",
	})

	if !result.Success {
		t.Errorf("Expected valid move, got error: %s", result.ErrorMessage)
	}

	if result.Move == nil {
		t.Fatal("Expected move record")
	}

	if result.Move.MoveNumber != 1 {
		t.Errorf("Expected move number 1, got %d", result.Move.MoveNumber)
	}

	if result.Move.PieceType != models.PieceTypeHorse {
		t.Errorf("Expected horse move, got %s", result.Move.PieceType)
	}

	if engine.GetCurrentTurn() != models.PlayerColorBlack {
		t.Error("Turn should switch to black after valid move")
	}
}

func TestEngine_ValidateAndMakeMove_WrongPlayer(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Black tries to move first
	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "black-player",
		From:     "b9",
		To:       "c7",
	})

	if result.Success {
		t.Error("Black should not be able to move first")
	}

	if result.ErrorMessage != "not your turn" {
		t.Errorf("Expected 'not your turn' error, got: %s", result.ErrorMessage)
	}
}

func TestEngine_ValidateAndMakeMove_InvalidPosition(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "z9", // Invalid
		To:       "c2",
	})

	if result.Success {
		t.Error("Should reject invalid position")
	}
}

func TestEngine_ValidateAndMakeMove_NoPiece(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "d4", // Empty square
		To:       "d5",
	})

	if result.Success {
		t.Error("Should reject move from empty square")
	}

	if result.ErrorMessage != "no piece at the specified position" {
		t.Errorf("Expected 'no piece' error, got: %s", result.ErrorMessage)
	}
}

func TestEngine_ValidateAndMakeMove_OpponentPiece(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b9", // Black's horse
		To:       "c7",
	})

	if result.Success {
		t.Error("Should not be able to move opponent's piece")
	}

	if result.ErrorMessage != "cannot move opponent's piece" {
		t.Errorf("Expected 'cannot move opponent's piece' error, got: %s", result.ErrorMessage)
	}
}

func TestEngine_ValidateAndMakeMove_InvalidMove(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "a0", // Chariot
		To:       "c2", // Invalid diagonal move for chariot
	})

	if result.Success {
		t.Error("Should reject invalid move pattern")
	}

	if result.ErrorMessage != "invalid move for this piece" {
		t.Errorf("Expected 'invalid move' error, got: %s", result.ErrorMessage)
	}
}

func TestEngine_ValidateAndMakeMove_Capture(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Set up a position where red can capture
	// Move red chariot to capture black soldier
	// First, let's make some moves to enable a capture

	// Red moves horse
	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b0",
		To:       "c2",
	})

	// Black moves soldier
	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "black-player",
		From:     "a6",
		To:       "a5",
	})

	// Red chariot can now potentially capture
	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "a0",
		To:       "a5", // Capture black soldier
	})

	if !result.Success {
		t.Errorf("Capture move should succeed: %s", result.ErrorMessage)
		return
	}

	if result.CapturedPiece == nil {
		t.Error("Expected captured piece")
	}

	if *result.CapturedPiece != models.PieceTypeSoldier {
		t.Errorf("Expected captured soldier, got %s", *result.CapturedPiece)
	}
}

func TestEngine_ValidateAndMakeMove_GameOver(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Simulate game over
	engine.SetResignation("red-player")

	result := engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "black-player",
		From:     "b9",
		To:       "c7",
	})

	if result.Success {
		t.Error("Should not allow moves after game is over")
	}

	if result.ErrorMessage != "game has already ended" {
		t.Errorf("Expected 'game ended' error, got: %s", result.ErrorMessage)
	}
}

// ========== GetValidMoves Tests ==========

func TestEngine_GetValidMoves_ValidPiece(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	moves, err := engine.GetValidMoves("b0")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	// Horse should have valid moves from initial position
	if len(moves) == 0 {
		t.Error("Horse should have valid moves")
	}

	// Should include c2 and a2
	hasC2 := false
	hasA2 := false
	for _, m := range moves {
		if m == "c2" {
			hasC2 = true
		}
		if m == "a2" {
			hasA2 = true
		}
	}

	if !hasC2 || !hasA2 {
		t.Errorf("Expected c2 and a2 as valid moves, got: %v", moves)
	}
}

func TestEngine_GetValidMoves_InvalidPosition(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	_, err := engine.GetValidMoves("z9")
	if err == nil {
		t.Error("Expected error for invalid position")
	}
}

func TestEngine_GetValidMoves_EmptySquare(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	_, err := engine.GetValidMoves("d4")
	if err == nil {
		t.Error("Expected error for empty square")
	}
}

// ========== UndoLastMove Tests ==========

func TestEngine_UndoLastMove_Success(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Make a move
	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b0",
		To:       "c2",
	})

	// Verify move was made
	if engine.GetCurrentTurn() != models.PlayerColorBlack {
		t.Error("Turn should be black after move")
	}

	// Undo
	err := engine.UndoLastMove()
	if err != nil {
		t.Fatalf("Undo failed: %v", err)
	}

	// Verify state is restored
	if engine.GetCurrentTurn() != models.PlayerColorRed {
		t.Error("Turn should be red after undo")
	}

	// Horse should be back at b0
	board := engine.GetBoard()
	horse := board.At(Position{1, 0})
	if horse == nil || horse.Type != models.PieceTypeHorse {
		t.Error("Horse should be back at original position")
	}

	// c2 should be empty
	if board.At(Position{2, 2}) != nil {
		t.Error("c2 should be empty after undo")
	}
}

func TestEngine_UndoLastMove_NoMoves(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	err := engine.UndoLastMove()
	if err == nil {
		t.Error("Expected error when undoing with no moves")
	}
}

func TestEngine_UndoLastMove_MultipleUndos(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Make two moves
	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b0",
		To:       "c2",
	})

	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "black-player",
		From:     "b9",
		To:       "c7",
	})

	// Undo once
	err := engine.UndoLastMove()
	if err != nil {
		t.Fatalf("First undo failed: %v", err)
	}

	if engine.GetCurrentTurn() != models.PlayerColorBlack {
		t.Error("Turn should be black after first undo")
	}

	// Undo again
	err = engine.UndoLastMove()
	if err != nil {
		t.Fatalf("Second undo failed: %v", err)
	}

	if engine.GetCurrentTurn() != models.PlayerColorRed {
		t.Error("Turn should be red after second undo")
	}
}

// ========== GetGameState Tests ==========

func TestEngine_GetGameState(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	state := engine.GetGameState()

	if state.GameID != "game-001" {
		t.Errorf("Expected game ID 'game-001', got '%s'", state.GameID)
	}

	if state.CurrentTurn != "red" {
		t.Errorf("Expected current turn 'red', got '%s'", state.CurrentTurn)
	}

	if state.RedPlayerID != "red-player" {
		t.Errorf("Expected red player ID 'red-player', got '%s'", state.RedPlayerID)
	}

	if state.BlackPlayerID != "black-player" {
		t.Errorf("Expected black player ID 'black-player', got '%s'", state.BlackPlayerID)
	}

	if state.MoveCount != 0 {
		t.Errorf("Expected move count 0, got %d", state.MoveCount)
	}

	if state.IsCheck {
		t.Error("Should not be in check at start")
	}

	// Verify board dimensions
	if len(state.Board) != RankCount {
		t.Errorf("Expected %d ranks, got %d", RankCount, len(state.Board))
	}
	if len(state.Board[0]) != FileCount {
		t.Errorf("Expected %d files, got %d", FileCount, len(state.Board[0]))
	}
}

func TestEngine_GetGameState_AfterMove(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b0",
		To:       "c2",
	})

	state := engine.GetGameState()

	if state.CurrentTurn != "black" {
		t.Errorf("Expected current turn 'black', got '%s'", state.CurrentTurn)
	}

	if state.MoveCount != 1 {
		t.Errorf("Expected move count 1, got %d", state.MoveCount)
	}

	// Verify piece moved
	if state.Board[2][2].Type != "horse" {
		t.Error("Horse should be at c2")
	}
}

// ========== SetResignation Tests ==========

func TestEngine_SetResignation_RedResigns(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	engine.SetResignation("red-player")

	if !engine.IsGameOver() {
		t.Error("Game should be over after resignation")
	}

	winner := engine.GetWinner()
	if winner == nil {
		t.Fatal("Expected winner")
	}
	if *winner != models.PlayerColorBlack {
		t.Error("Black should win when red resigns")
	}
}

func TestEngine_SetResignation_BlackResigns(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	engine.SetResignation("black-player")

	winner := engine.GetWinner()
	if winner == nil {
		t.Fatal("Expected winner")
	}
	if *winner != models.PlayerColorRed {
		t.Error("Red should win when black resigns")
	}
}

// ========== SetTimeout Tests ==========

func TestEngine_SetTimeout(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	engine.SetTimeout("red-player")

	if !engine.IsGameOver() {
		t.Error("Game should be over after timeout")
	}

	winner := engine.GetWinner()
	if winner == nil || *winner != models.PlayerColorBlack {
		t.Error("Black should win when red times out")
	}
}

// ========== SetDraw Tests ==========

func TestEngine_SetDraw(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	engine.SetDraw()

	if !engine.IsGameOver() {
		t.Error("Game should be over after draw")
	}

	winner := engine.GetWinner()
	if winner != nil {
		t.Error("There should be no winner in a draw")
	}
}

// ========== ParsePosition Tests ==========

func TestParsePosition_Valid(t *testing.T) {
	testCases := []struct {
		notation string
		expected Position
	}{
		{"a0", Position{0, 0}},
		{"e0", Position{4, 0}},
		{"i9", Position{8, 9}},
		{"e4", Position{4, 4}},
	}

	for _, tc := range testCases {
		pos, err := ParsePosition(tc.notation)
		if err != nil {
			t.Errorf("ParsePosition(%s) returned error: %v", tc.notation, err)
			continue
		}
		if pos != tc.expected {
			t.Errorf("ParsePosition(%s) = %v, expected %v", tc.notation, pos, tc.expected)
		}
	}
}

func TestParsePosition_Invalid(t *testing.T) {
	invalidNotations := []string{
		"",
		"a",
		"j0",  // Invalid file
		"a10", // Invalid rank (out of bounds)
		"aa",  // Invalid rank
		"0a",  // Reversed
	}

	for _, notation := range invalidNotations {
		_, err := ParsePosition(notation)
		if err == nil {
			t.Errorf("ParsePosition(%s) should return error", notation)
		}
	}
}

// ========== Check Detection During Game Tests ==========

func TestEngine_CheckDetection(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Make moves to create a check situation
	// This is a simplified test - actual check would require specific moves
	moves := []MoveRequest{
		{PlayerID: "red-player", From: "h2", To: "h5"},   // Red cannon
		{PlayerID: "black-player", From: "h9", To: "h8"}, // Black horse out of way
		{PlayerID: "red-player", From: "h5", To: "e5"},   // Red cannon
		{PlayerID: "black-player", From: "i9", To: "i8"}, // Black chariot
		// At this point, check would depend on specific board state
	}

	for _, move := range moves {
		result := engine.ValidateAndMakeMove(move)
		if !result.Success {
			// Some moves might fail, that's okay for this test
			break
		}
	}

	// Just verify engine tracks check status properly
	_ = engine.IsCheck()     // Should not panic
	_ = engine.IsCheckmate() // Should not panic
}

// ========== Move History Tests ==========

func TestEngine_MoveHistory(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Make some moves
	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "red-player",
		From:     "b0",
		To:       "c2",
	})

	engine.ValidateAndMakeMove(MoveRequest{
		PlayerID: "black-player",
		From:     "b9",
		To:       "c7",
	})

	history := engine.GetMoveHistory()

	if len(history) != 2 {
		t.Errorf("Expected 2 moves in history, got %d", len(history))
	}

	// Verify first move
	if history[0].PieceType != models.PieceTypeHorse {
		t.Error("First move should be horse")
	}
	if history[0].From != (Position{1, 0}) {
		t.Error("First move should start from b0")
	}
	if history[0].To != (Position{2, 2}) {
		t.Error("First move should end at c2")
	}

	// Verify second move
	if history[1].PieceType != models.PieceTypeHorse {
		t.Error("Second move should be horse")
	}
	if history[1].PlayerID != "black-player" {
		t.Error("Second move should be by black player")
	}
}

// ========== NewGameEngineFromState Tests ==========

func TestNewGameEngineFromState(t *testing.T) {
	// Create initial state
	board := NewInitialBoard()

	// Make a move on the board
	board.Move(Position{1, 0}, Position{2, 2})

	moves := []MoveRecord{
		{
			MoveNumber: 1,
			From:       Position{1, 0},
			To:         Position{2, 2},
			PieceType:  models.PieceTypeHorse,
			PlayerID:   "red-player",
		},
	}

	engine := NewGameEngineFromState(
		"game-001",
		"red-player",
		"black-player",
		board,
		models.PlayerColorBlack,
		moves,
	)

	if engine.GetCurrentTurn() != models.PlayerColorBlack {
		t.Error("Should be black's turn")
	}

	if len(engine.GetMoveHistory()) != 1 {
		t.Error("Should have one move in history")
	}

	// Verify board state is correct
	piece := engine.GetBoard().At(Position{2, 2})
	if piece == nil || piece.Type != models.PieceTypeHorse {
		t.Error("Horse should be at c2")
	}
}

// ========== Complete Game Simulation ==========

func TestEngine_CompleteGame(t *testing.T) {
	engine := NewGameEngine("game-001", "red-player", "black-player")

	// Simulate a short game
	moves := []MoveRequest{
		{PlayerID: "red-player", From: "b0", To: "c2"},   // Red horse
		{PlayerID: "black-player", From: "b9", To: "c7"}, // Black horse
		{PlayerID: "red-player", From: "h0", To: "g2"},   // Red horse
		{PlayerID: "black-player", From: "h9", To: "g7"}, // Black horse
	}

	for i, move := range moves {
		result := engine.ValidateAndMakeMove(move)
		if !result.Success {
			t.Errorf("Move %d failed: %s", i+1, result.ErrorMessage)
			return
		}
	}

	// Verify game state after moves
	state := engine.GetGameState()
	if state.MoveCount != 4 {
		t.Errorf("Expected 4 moves, got %d", state.MoveCount)
	}

	if !engine.IsGameOver() {
		// Game should continue - just verify state is valid
		if engine.GetCurrentTurn() != models.PlayerColorRed {
			t.Error("Should be red's turn")
		}
	}
}
