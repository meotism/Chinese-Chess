// Package game implements the Xiangqi (Chinese Chess) game logic.
package game

import "github.com/xiangqi/chinese-chess-backend/internal/models"

// RulesEngine provides methods for checking game rules and conditions.
type RulesEngine struct{}

// NewRulesEngine creates a new RulesEngine.
func NewRulesEngine() *RulesEngine {
	return &RulesEngine{}
}

// IsFlyingGeneral checks if the two generals would be facing each other
// with no pieces between them after a move.
// This rule prevents the generals from being on the same file with no pieces between.
func (r *RulesEngine) IsFlyingGeneral(board *Board) bool {
	redGeneral := board.GetGeneral(models.PlayerColorRed)
	blackGeneral := board.GetGeneral(models.PlayerColorBlack)

	if redGeneral == nil || blackGeneral == nil {
		return false
	}

	// Generals must be on the same file for flying general to apply
	if redGeneral.Position.File != blackGeneral.Position.File {
		return false
	}

	// Check if there are any pieces between the generals
	minRank := redGeneral.Position.Rank + 1
	maxRank := blackGeneral.Position.Rank
	file := redGeneral.Position.File

	for rank := minRank; rank < maxRank; rank++ {
		if board.HasPiece(Position{file, rank}) {
			return false // There's a piece between, no flying general
		}
	}

	// No pieces between - this would be flying general
	return true
}

// IsInCheck returns true if the specified color's general is in check.
func (r *RulesEngine) IsInCheck(board *Board, color models.PlayerColor) bool {
	general := board.GetGeneral(color)
	if general == nil {
		return false
	}

	generalPos := general.Position

	// Check if any enemy piece can attack the general
	enemyColor := models.PlayerColorBlack
	if color == models.PlayerColorBlack {
		enemyColor = models.PlayerColorRed
	}

	enemyPieces := board.GetPieces(enemyColor)
	for _, piece := range enemyPieces {
		validator := GetValidator(piece.Type)
		if validator == nil {
			continue
		}

		// Check if this piece can capture the general
		if validator.IsValidMove(piece, generalPos, board) {
			return true
		}
	}

	// Also check for flying general (general facing general)
	enemyGeneral := board.GetGeneral(enemyColor)
	if enemyGeneral != nil && enemyGeneral.Position.File == generalPos.File {
		// Check if there are no pieces between
		minRank := generalPos.Rank
		maxRank := enemyGeneral.Position.Rank
		if minRank > maxRank {
			minRank, maxRank = maxRank, minRank
		}

		hasPieceBetween := false
		for rank := minRank + 1; rank < maxRank; rank++ {
			if board.HasPiece(Position{generalPos.File, rank}) {
				hasPieceBetween = true
				break
			}
		}

		if !hasPieceBetween {
			return true // Flying general - opponent's general is attacking
		}
	}

	return false
}

// GetCheckingPieces returns all pieces that are giving check to the specified color's general.
func (r *RulesEngine) GetCheckingPieces(board *Board, color models.PlayerColor) []*Piece {
	general := board.GetGeneral(color)
	if general == nil {
		return nil
	}

	generalPos := general.Position
	var checkingPieces []*Piece

	// Get enemy color
	enemyColor := models.PlayerColorBlack
	if color == models.PlayerColorBlack {
		enemyColor = models.PlayerColorRed
	}

	enemyPieces := board.GetPieces(enemyColor)
	for _, piece := range enemyPieces {
		validator := GetValidator(piece.Type)
		if validator == nil {
			continue
		}

		if validator.IsValidMove(piece, generalPos, board) {
			checkingPieces = append(checkingPieces, piece)
		}
	}

	return checkingPieces
}

// HasLegalMoves returns true if the specified color has any legal moves.
func (r *RulesEngine) HasLegalMoves(board *Board, color models.PlayerColor) bool {
	pieces := board.GetPieces(color)

	for _, piece := range pieces {
		validator := GetValidator(piece.Type)
		if validator == nil {
			continue
		}

		validMoves := validator.GetValidMoves(piece, board)
		for _, to := range validMoves {
			// Simulate the move
			testBoard := board.Copy()
			testBoard.Move(piece.Position, to)

			// Check if this move would leave the general in check
			if !r.IsInCheck(testBoard, color) && !r.IsFlyingGeneral(testBoard) {
				return true // Found at least one legal move
			}
		}
	}

	return false
}

// IsCheckmate returns true if the specified color is in checkmate.
// Checkmate occurs when:
// 1. The general is in check
// 2. There are no legal moves to escape check
func (r *RulesEngine) IsCheckmate(board *Board, color models.PlayerColor) bool {
	if !r.IsInCheck(board, color) {
		return false
	}

	return !r.HasLegalMoves(board, color)
}

// IsStalemate returns true if the specified color is in stalemate.
// Stalemate occurs when:
// 1. The general is NOT in check
// 2. There are no legal moves
// Note: In Xiangqi, stalemate is typically a loss for the stalemated player.
func (r *RulesEngine) IsStalemate(board *Board, color models.PlayerColor) bool {
	if r.IsInCheck(board, color) {
		return false
	}

	return !r.HasLegalMoves(board, color)
}

// GetLegalMoves returns all legal moves for a piece, filtering out moves
// that would leave the general in check or create a flying general situation.
func (r *RulesEngine) GetLegalMoves(piece *Piece, board *Board) []Position {
	validator := GetValidator(piece.Type)
	if validator == nil {
		return nil
	}

	validMoves := validator.GetValidMoves(piece, board)
	var legalMoves []Position

	for _, to := range validMoves {
		// Simulate the move
		testBoard := board.Copy()
		testBoard.Move(piece.Position, to)

		// Check if this move would leave the general in check or create flying general
		if !r.IsInCheck(testBoard, piece.Color) && !r.IsFlyingGeneral(testBoard) {
			legalMoves = append(legalMoves, to)
		}
	}

	return legalMoves
}

// IsValidMove checks if a move is valid considering all rules.
// This includes piece movement rules, check rules, and flying general rule.
func (r *RulesEngine) IsValidMove(piece *Piece, to Position, board *Board) bool {
	// First, check basic piece movement rules
	validator := GetValidator(piece.Type)
	if validator == nil {
		return false
	}

	if !validator.IsValidMove(piece, to, board) {
		return false
	}

	// Simulate the move
	testBoard := board.Copy()
	testBoard.Move(piece.Position, to)

	// Check if this move would leave the general in check
	if r.IsInCheck(testBoard, piece.Color) {
		return false
	}

	// Check for flying general
	if r.IsFlyingGeneral(testBoard) {
		return false
	}

	return true
}

// CanCapture checks if a piece at 'from' can legally capture a piece at 'to'.
func (r *RulesEngine) CanCapture(from, to Position, board *Board) bool {
	piece := board.At(from)
	if piece == nil {
		return false
	}

	target := board.At(to)
	if target == nil {
		return false
	}

	// Cannot capture own pieces
	if piece.Color == target.Color {
		return false
	}

	return r.IsValidMove(piece, to, board)
}

// WouldExposeGeneral checks if a move would expose the general to check.
func (r *RulesEngine) WouldExposeGeneral(piece *Piece, to Position, board *Board) bool {
	testBoard := board.Copy()
	testBoard.Move(piece.Position, to)
	return r.IsInCheck(testBoard, piece.Color)
}

// GetAllLegalMoves returns all legal moves for a color.
func (r *RulesEngine) GetAllLegalMoves(board *Board, color models.PlayerColor) []Move {
	var moves []Move
	pieces := board.GetPieces(color)

	for _, piece := range pieces {
		legalMoves := r.GetLegalMoves(piece, board)
		for _, to := range legalMoves {
			captured := board.At(to)
			var capturedType *models.PieceType
			if captured != nil {
				ct := captured.Type
				capturedType = &ct
			}

			// Create move and check if it results in check
			testBoard := board.Copy()
			testBoard.Move(piece.Position, to)
			isCheck := r.IsInCheck(testBoard, color.Opposite())

			moves = append(moves, Move{
				From:          piece.Position,
				To:            to,
				PieceType:     piece.Type,
				CapturedPiece: capturedType,
				IsCheck:       isCheck,
			})
		}
	}

	return moves
}

// Move represents a move in the game.
type Move struct {
	From          Position
	To            Position
	PieceType     models.PieceType
	CapturedPiece *models.PieceType
	IsCheck       bool
}

// Opposite returns the opposite color.
func (c models.PlayerColor) Opposite() models.PlayerColor {
	if c == models.PlayerColorRed {
		return models.PlayerColorBlack
	}
	return models.PlayerColorRed
}
