// Package game implements the Xiangqi (Chinese Chess) game logic.
package game

import (
	"errors"
	"time"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// GameEngine manages the state and logic for a single game.
type GameEngine struct {
	board       *Board
	currentTurn models.PlayerColor
	rules       *RulesEngine
	moveHistory []MoveRecord
	gameID      string
	redPlayerID string
	blackPlayerID string
	isCheck     bool
	isCheckmate bool
	isStalemate bool
	winner      *models.PlayerColor
}

// MoveRecord records a move with all its details.
type MoveRecord struct {
	MoveNumber    int
	From          Position
	To            Position
	PieceType     models.PieceType
	CapturedPiece *models.PieceType
	IsCheck       bool
	Timestamp     time.Time
	PlayerID      string
}

// NewGameEngine creates a new game engine with the initial board position.
func NewGameEngine(gameID, redPlayerID, blackPlayerID string) *GameEngine {
	return &GameEngine{
		board:         NewInitialBoard(),
		currentTurn:   models.PlayerColorRed,
		rules:         NewRulesEngine(),
		moveHistory:   make([]MoveRecord, 0),
		gameID:        gameID,
		redPlayerID:   redPlayerID,
		blackPlayerID: blackPlayerID,
		isCheck:       false,
		isCheckmate:   false,
		isStalemate:   false,
		winner:        nil,
	}
}

// NewGameEngineFromState creates a game engine from an existing state.
func NewGameEngineFromState(gameID, redPlayerID, blackPlayerID string, board *Board, currentTurn models.PlayerColor, moves []MoveRecord) *GameEngine {
	engine := &GameEngine{
		board:         board,
		currentTurn:   currentTurn,
		rules:         NewRulesEngine(),
		moveHistory:   moves,
		gameID:        gameID,
		redPlayerID:   redPlayerID,
		blackPlayerID: blackPlayerID,
	}

	// Recalculate check status
	engine.isCheck = engine.rules.IsInCheck(board, currentTurn)
	engine.isCheckmate = engine.rules.IsCheckmate(board, currentTurn)
	engine.isStalemate = engine.rules.IsStalemate(board, currentTurn)

	return engine
}

// GetBoard returns the current board state.
func (e *GameEngine) GetBoard() *Board {
	return e.board
}

// GetCurrentTurn returns the color of the player to move.
func (e *GameEngine) GetCurrentTurn() models.PlayerColor {
	return e.currentTurn
}

// IsCheck returns true if the current player is in check.
func (e *GameEngine) IsCheck() bool {
	return e.isCheck
}

// IsCheckmate returns true if the current player is in checkmate.
func (e *GameEngine) IsCheckmate() bool {
	return e.isCheckmate
}

// IsStalemate returns true if the current player is in stalemate.
func (e *GameEngine) IsStalemate() bool {
	return e.isStalemate
}

// IsGameOver returns true if the game has ended.
func (e *GameEngine) IsGameOver() bool {
	return e.isCheckmate || e.isStalemate || e.winner != nil
}

// GetWinner returns the winner if the game is over.
func (e *GameEngine) GetWinner() *models.PlayerColor {
	return e.winner
}

// GetMoveHistory returns all moves made in the game.
func (e *GameEngine) GetMoveHistory() []MoveRecord {
	return e.moveHistory
}

// ValidateMoveRequest validates a move request from a player.
type MoveRequest struct {
	PlayerID string
	From     string // Notation like "e0"
	To       string // Notation like "e1"
}

// MoveResult contains the result of a move attempt.
type MoveResult struct {
	Success       bool
	ErrorMessage  string
	Move          *MoveRecord
	IsCheck       bool
	IsCheckmate   bool
	IsStalemate   bool
	CapturedPiece *models.PieceType
	WinnerID      *string
}

// ValidateAndMakeMove validates and executes a move.
func (e *GameEngine) ValidateAndMakeMove(req MoveRequest) MoveResult {
	// Check if game is already over
	if e.IsGameOver() {
		return MoveResult{
			Success:      false,
			ErrorMessage: "game has already ended",
		}
	}

	// Verify it's the player's turn
	expectedPlayerID := e.redPlayerID
	if e.currentTurn == models.PlayerColorBlack {
		expectedPlayerID = e.blackPlayerID
	}

	if req.PlayerID != expectedPlayerID {
		return MoveResult{
			Success:      false,
			ErrorMessage: "not your turn",
		}
	}

	// Parse positions
	fromPos, err := ParsePosition(req.From)
	if err != nil {
		return MoveResult{
			Success:      false,
			ErrorMessage: "invalid from position: " + err.Error(),
		}
	}

	toPos, err := ParsePosition(req.To)
	if err != nil {
		return MoveResult{
			Success:      false,
			ErrorMessage: "invalid to position: " + err.Error(),
		}
	}

	// Get the piece at the from position
	piece := e.board.At(fromPos)
	if piece == nil {
		return MoveResult{
			Success:      false,
			ErrorMessage: "no piece at the specified position",
		}
	}

	// Verify the piece belongs to the current player
	if piece.Color != e.currentTurn {
		return MoveResult{
			Success:      false,
			ErrorMessage: "cannot move opponent's piece",
		}
	}

	// Validate the move using the rules engine
	if !e.rules.IsValidMove(piece, toPos, e.board) {
		return MoveResult{
			Success:      false,
			ErrorMessage: "invalid move for this piece",
		}
	}

	// Execute the move
	captured := e.board.Move(fromPos, toPos)
	var capturedType *models.PieceType
	if captured != nil {
		ct := captured.Type
		capturedType = &ct
	}

	// Switch turn
	e.currentTurn = e.currentTurn.Opposite()

	// Check game state after move
	e.isCheck = e.rules.IsInCheck(e.board, e.currentTurn)
	e.isCheckmate = e.rules.IsCheckmate(e.board, e.currentTurn)
	e.isStalemate = e.rules.IsStalemate(e.board, e.currentTurn)

	// Determine winner if game is over
	var winnerID *string
	if e.isCheckmate || e.isStalemate {
		// The player who just moved wins (opponent has no moves)
		if e.currentTurn == models.PlayerColorRed {
			winnerID = &e.blackPlayerID
			winner := models.PlayerColorBlack
			e.winner = &winner
		} else {
			winnerID = &e.redPlayerID
			winner := models.PlayerColorRed
			e.winner = &winner
		}
	}

	// Also check if the general was captured (instant win)
	if captured != nil && captured.Type == models.PieceTypeGeneral {
		if captured.Color == models.PlayerColorRed {
			winnerID = &e.blackPlayerID
			winner := models.PlayerColorBlack
			e.winner = &winner
		} else {
			winnerID = &e.redPlayerID
			winner := models.PlayerColorRed
			e.winner = &winner
		}
	}

	// Record the move
	moveRecord := MoveRecord{
		MoveNumber:    len(e.moveHistory) + 1,
		From:          fromPos,
		To:            toPos,
		PieceType:     piece.Type,
		CapturedPiece: capturedType,
		IsCheck:       e.isCheck,
		Timestamp:     time.Now(),
		PlayerID:      req.PlayerID,
	}
	e.moveHistory = append(e.moveHistory, moveRecord)

	return MoveResult{
		Success:       true,
		Move:          &moveRecord,
		IsCheck:       e.isCheck,
		IsCheckmate:   e.isCheckmate,
		IsStalemate:   e.isStalemate,
		CapturedPiece: capturedType,
		WinnerID:      winnerID,
	}
}

// GetValidMoves returns all valid moves for a piece at the given position.
func (e *GameEngine) GetValidMoves(pos string) ([]string, error) {
	position, err := ParsePosition(pos)
	if err != nil {
		return nil, err
	}

	piece := e.board.At(position)
	if piece == nil {
		return nil, errors.New("no piece at the specified position")
	}

	legalMoves := e.rules.GetLegalMoves(piece, e.board)
	result := make([]string, len(legalMoves))
	for i, move := range legalMoves {
		result[i] = move.Notation()
	}

	return result, nil
}

// UndoLastMove reverts the last move (for rollback functionality).
func (e *GameEngine) UndoLastMove() error {
	if len(e.moveHistory) == 0 {
		return errors.New("no moves to undo")
	}

	// This is a simplified implementation
	// In a full implementation, we would need to store more state
	// to properly restore captured pieces and other game state

	// For now, we'll rebuild the board from scratch by replaying moves
	e.board = NewInitialBoard()
	e.currentTurn = models.PlayerColorRed

	// Replay all moves except the last one
	moves := e.moveHistory[:len(e.moveHistory)-1]
	e.moveHistory = make([]MoveRecord, 0)

	for _, move := range moves {
		e.board.Move(move.From, move.To)
		e.currentTurn = e.currentTurn.Opposite()
		e.moveHistory = append(e.moveHistory, move)
	}

	// Recalculate check status
	e.isCheck = e.rules.IsInCheck(e.board, e.currentTurn)
	e.isCheckmate = false
	e.isStalemate = false
	e.winner = nil

	return nil
}

// GetGameState returns the current game state for serialization.
func (e *GameEngine) GetGameState() *GameState {
	boardState := make([][]PieceState, RankCount)
	for rank := 0; rank < RankCount; rank++ {
		boardState[rank] = make([]PieceState, FileCount)
		for file := 0; file < FileCount; file++ {
			piece := e.board.At(Position{file, rank})
			if piece != nil {
				boardState[rank][file] = PieceState{
					Type:  string(piece.Type),
					Color: string(piece.Color),
				}
			}
		}
	}

	return &GameState{
		GameID:        e.gameID,
		Board:         boardState,
		CurrentTurn:   string(e.currentTurn),
		IsCheck:       e.isCheck,
		IsCheckmate:   e.isCheckmate,
		IsStalemate:   e.isStalemate,
		MoveCount:     len(e.moveHistory),
		RedPlayerID:   e.redPlayerID,
		BlackPlayerID: e.blackPlayerID,
	}
}

// GameState represents the serializable state of a game.
type GameState struct {
	GameID        string          `json:"game_id"`
	Board         [][]PieceState  `json:"board"`
	CurrentTurn   string          `json:"current_turn"`
	IsCheck       bool            `json:"is_check"`
	IsCheckmate   bool            `json:"is_checkmate"`
	IsStalemate   bool            `json:"is_stalemate"`
	MoveCount     int             `json:"move_count"`
	RedPlayerID   string          `json:"red_player_id"`
	BlackPlayerID string          `json:"black_player_id"`
}

// PieceState represents a piece for serialization.
type PieceState struct {
	Type  string `json:"type,omitempty"`
	Color string `json:"color,omitempty"`
}

// ParsePosition parses a position notation string (e.g., "e4") into a Position.
func ParsePosition(notation string) (Position, error) {
	if len(notation) < 2 {
		return Position{}, errors.New("notation too short")
	}

	fileChar := notation[0]
	if fileChar < 'a' || fileChar > 'i' {
		return Position{}, errors.New("invalid file character")
	}
	file := int(fileChar - 'a')

	rankStr := notation[1:]
	rank := 0
	for _, c := range rankStr {
		if c < '0' || c > '9' {
			return Position{}, errors.New("invalid rank character")
		}
		rank = rank*10 + int(c-'0')
	}

	if rank < 0 || rank >= RankCount {
		return Position{}, errors.New("rank out of bounds")
	}

	return Position{File: file, Rank: rank}, nil
}

// SetResignation marks a player as having resigned.
func (e *GameEngine) SetResignation(resigningPlayerID string) {
	if resigningPlayerID == e.redPlayerID {
		winner := models.PlayerColorBlack
		e.winner = &winner
	} else if resigningPlayerID == e.blackPlayerID {
		winner := models.PlayerColorRed
		e.winner = &winner
	}
}

// SetTimeout marks a player as having timed out.
func (e *GameEngine) SetTimeout(timedOutPlayerID string) {
	e.SetResignation(timedOutPlayerID) // Same effect as resignation
}

// SetDraw marks the game as a draw.
func (e *GameEngine) SetDraw() {
	e.winner = nil
	e.isStalemate = true // Use stalemate to indicate game over with no winner
}
