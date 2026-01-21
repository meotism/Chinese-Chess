// Package game implements the Xiangqi (Chinese Chess) game logic.
package game

import "github.com/xiangqi/chinese-chess-backend/internal/models"

// MoveValidator is an interface for validating piece moves.
type MoveValidator interface {
	// GetValidMoves returns all valid destination positions for a piece.
	GetValidMoves(piece *Piece, board *Board) []Position

	// IsValidMove checks if a specific move is valid.
	IsValidMove(piece *Piece, to Position, board *Board) bool
}

// GetValidator returns the appropriate validator for a piece type.
func GetValidator(pieceType models.PieceType) MoveValidator {
	switch pieceType {
	case models.PieceTypeGeneral:
		return &GeneralValidator{}
	case models.PieceTypeAdvisor:
		return &AdvisorValidator{}
	case models.PieceTypeElephant:
		return &ElephantValidator{}
	case models.PieceTypeHorse:
		return &HorseValidator{}
	case models.PieceTypeChariot:
		return &ChariotValidator{}
	case models.PieceTypeCannon:
		return &CannonValidator{}
	case models.PieceTypeSoldier:
		return &SoldierValidator{}
	default:
		return nil
	}
}

// GeneralValidator validates moves for the General (King).
// The General moves one step orthogonally and must stay within the palace.
type GeneralValidator struct{}

// GetValidMoves returns all valid moves for the General.
func (v *GeneralValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// Orthogonal offsets (up, down, left, right)
	offsets := []struct{ file, rank int }{
		{0, 1}, {0, -1}, {1, 0}, {-1, 0},
	}

	for _, offset := range offsets {
		to := from.Offset(offset.file, offset.rank)
		if v.IsValidMove(piece, to, board) {
			moves = append(moves, to)
		}
	}

	return moves
}

// IsValidMove checks if a move is valid for the General.
func (v *GeneralValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Must stay within the palace
	if !to.IsInPalace(piece.Color) {
		return false
	}

	// Must move exactly one step orthogonally
	fileDiff := Abs(to.File - from.File)
	rankDiff := Abs(to.Rank - from.Rank)

	if !((fileDiff == 1 && rankDiff == 0) || (fileDiff == 0 && rankDiff == 1)) {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	return true
}

// AdvisorValidator validates moves for the Advisor (Guard).
// The Advisor moves one step diagonally and must stay within the palace.
type AdvisorValidator struct{}

// GetValidMoves returns all valid moves for the Advisor.
func (v *AdvisorValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// Diagonal offsets
	offsets := []struct{ file, rank int }{
		{1, 1}, {1, -1}, {-1, 1}, {-1, -1},
	}

	for _, offset := range offsets {
		to := from.Offset(offset.file, offset.rank)
		if v.IsValidMove(piece, to, board) {
			moves = append(moves, to)
		}
	}

	return moves
}

// IsValidMove checks if a move is valid for the Advisor.
func (v *AdvisorValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Must stay within the palace
	if !to.IsInPalace(piece.Color) {
		return false
	}

	// Must move exactly one step diagonally
	fileDiff := Abs(to.File - from.File)
	rankDiff := Abs(to.Rank - from.Rank)

	if fileDiff != 1 || rankDiff != 1 {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	return true
}

// ElephantValidator validates moves for the Elephant (Bishop).
// The Elephant moves two steps diagonally and cannot cross the river.
// It can be blocked by a piece at the intermediate position.
type ElephantValidator struct{}

// GetValidMoves returns all valid moves for the Elephant.
func (v *ElephantValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// Diagonal offsets (2 steps)
	offsets := []struct{ file, rank int }{
		{2, 2}, {2, -2}, {-2, 2}, {-2, -2},
	}

	for _, offset := range offsets {
		to := from.Offset(offset.file, offset.rank)
		if v.IsValidMove(piece, to, board) {
			moves = append(moves, to)
		}
	}

	return moves
}

// IsValidMove checks if a move is valid for the Elephant.
func (v *ElephantValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Must move exactly two steps diagonally
	fileDiff := Abs(to.File - from.File)
	rankDiff := Abs(to.Rank - from.Rank)

	if fileDiff != 2 || rankDiff != 2 {
		return false
	}

	// Cannot cross the river
	if piece.Color == models.PlayerColorRed && to.IsOnBlackSide() {
		return false
	}
	if piece.Color == models.PlayerColorBlack && to.IsOnRedSide() {
		return false
	}

	// Check for blocking piece at intermediate position (elephant eye)
	midFile := (from.File + to.File) / 2
	midRank := (from.Rank + to.Rank) / 2
	midPos := Position{midFile, midRank}

	if board.HasPiece(midPos) {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	return true
}

// HorseValidator validates moves for the Horse (Knight).
// The Horse moves in an L-shape: one step orthogonally, then one step diagonally.
// It can be blocked by a piece at the adjacent orthogonal position.
type HorseValidator struct{}

// GetValidMoves returns all valid moves for the Horse.
func (v *HorseValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// L-shaped moves with their blocking positions
	horseMoves := []struct {
		fileOffset   int
		rankOffset   int
		blockingFile int
		blockingRank int
	}{
		// Moving up first
		{1, 2, 0, 1},   // Up, then right
		{-1, 2, 0, 1},  // Up, then left
		{1, -2, 0, -1}, // Down, then right
		{-1, -2, 0, -1}, // Down, then left
		// Moving sideways first
		{2, 1, 1, 0},   // Right, then up
		{2, -1, 1, 0},  // Right, then down
		{-2, 1, -1, 0}, // Left, then up
		{-2, -1, -1, 0}, // Left, then down
	}

	for _, move := range horseMoves {
		to := from.Offset(move.fileOffset, move.rankOffset)
		blocking := from.Offset(move.blockingFile, move.blockingRank)

		if !to.IsValid() {
			continue
		}

		// Check for blocking piece (horse leg)
		if board.HasPiece(blocking) {
			continue
		}

		// Cannot capture own piece
		if board.HasFriendly(to, piece.Color) {
			continue
		}

		moves = append(moves, to)
	}

	return moves
}

// IsValidMove checks if a move is valid for the Horse.
func (v *HorseValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Calculate file and rank differences
	fileDiff := Abs(to.File - from.File)
	rankDiff := Abs(to.Rank - from.Rank)

	// Must be L-shape: (1,2) or (2,1)
	if !((fileDiff == 1 && rankDiff == 2) || (fileDiff == 2 && rankDiff == 1)) {
		return false
	}

	// Determine blocking position based on direction
	var blockingFile, blockingRank int
	if rankDiff == 2 {
		// Moving primarily vertical, blocked by adjacent vertical square
		blockingFile = from.File
		if to.Rank > from.Rank {
			blockingRank = from.Rank + 1
		} else {
			blockingRank = from.Rank - 1
		}
	} else {
		// Moving primarily horizontal, blocked by adjacent horizontal square
		blockingRank = from.Rank
		if to.File > from.File {
			blockingFile = from.File + 1
		} else {
			blockingFile = from.File - 1
		}
	}

	// Check for blocking piece
	if board.HasPiece(Position{blockingFile, blockingRank}) {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	return true
}

// ChariotValidator validates moves for the Chariot (Rook).
// The Chariot moves any number of steps orthogonally.
type ChariotValidator struct{}

// GetValidMoves returns all valid moves for the Chariot.
func (v *ChariotValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// Check all four directions
	directions := []struct{ file, rank int }{
		{0, 1},  // Up
		{0, -1}, // Down
		{1, 0},  // Right
		{-1, 0}, // Left
	}

	for _, dir := range directions {
		for i := 1; i < 10; i++ {
			to := from.Offset(dir.file*i, dir.rank*i)
			if !to.IsValid() {
				break
			}

			if board.IsEmpty(to) {
				moves = append(moves, to)
			} else if board.HasEnemy(to, piece.Color) {
				moves = append(moves, to)
				break // Cannot go past a captured piece
			} else {
				break // Blocked by friendly piece
			}
		}
	}

	return moves
}

// IsValidMove checks if a move is valid for the Chariot.
func (v *ChariotValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Must move orthogonally
	if from.File != to.File && from.Rank != to.Rank {
		return false
	}

	// Cannot stay in place
	if from.File == to.File && from.Rank == to.Rank {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	// Check path for obstacles
	if from.File == to.File {
		// Moving vertically
		step := 1
		if to.Rank < from.Rank {
			step = -1
		}
		for rank := from.Rank + step; rank != to.Rank; rank += step {
			if board.HasPiece(Position{from.File, rank}) {
				return false
			}
		}
	} else {
		// Moving horizontally
		step := 1
		if to.File < from.File {
			step = -1
		}
		for file := from.File + step; file != to.File; file += step {
			if board.HasPiece(Position{file, from.Rank}) {
				return false
			}
		}
	}

	return true
}

// CannonValidator validates moves for the Cannon.
// The Cannon moves like the Chariot for non-capturing moves.
// For captures, it must jump over exactly one piece (the screen).
type CannonValidator struct{}

// GetValidMoves returns all valid moves for the Cannon.
func (v *CannonValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// Check all four directions
	directions := []struct{ file, rank int }{
		{0, 1},  // Up
		{0, -1}, // Down
		{1, 0},  // Right
		{-1, 0}, // Left
	}

	for _, dir := range directions {
		foundScreen := false
		for i := 1; i < 10; i++ {
			to := from.Offset(dir.file*i, dir.rank*i)
			if !to.IsValid() {
				break
			}

			if !foundScreen {
				// Before finding screen, can move to empty squares
				if board.IsEmpty(to) {
					moves = append(moves, to)
				} else {
					// Found the screen
					foundScreen = true
				}
			} else {
				// After finding screen, can only capture
				if board.HasEnemy(to, piece.Color) {
					moves = append(moves, to)
					break
				} else if board.HasFriendly(to, piece.Color) {
					break // Blocked by second friendly piece
				}
				// If empty, continue looking for capture target
			}
		}
	}

	return moves
}

// IsValidMove checks if a move is valid for the Cannon.
func (v *CannonValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Must move orthogonally
	if from.File != to.File && from.Rank != to.Rank {
		return false
	}

	// Cannot stay in place
	if from.File == to.File && from.Rank == to.Rank {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	// Count pieces between from and to
	piecesInPath := 0
	if from.File == to.File {
		// Moving vertically
		step := 1
		if to.Rank < from.Rank {
			step = -1
		}
		for rank := from.Rank + step; rank != to.Rank; rank += step {
			if board.HasPiece(Position{from.File, rank}) {
				piecesInPath++
			}
		}
	} else {
		// Moving horizontally
		step := 1
		if to.File < from.File {
			step = -1
		}
		for file := from.File + step; file != to.File; file += step {
			if board.HasPiece(Position{file, from.Rank}) {
				piecesInPath++
			}
		}
	}

	// Determine if this is a capture move
	isCapture := board.HasEnemy(to, piece.Color)

	if isCapture {
		// For capture, must have exactly one piece (screen) between
		return piecesInPath == 1
	} else {
		// For non-capture, must have no pieces between
		return piecesInPath == 0
	}
}

// SoldierValidator validates moves for the Soldier (Pawn).
// Before crossing the river: moves one step forward only.
// After crossing the river: moves one step forward or sideways.
type SoldierValidator struct{}

// GetValidMoves returns all valid moves for the Soldier.
func (v *SoldierValidator) GetValidMoves(piece *Piece, board *Board) []Position {
	var moves []Position
	from := piece.Position

	// Determine forward direction based on color
	forward := 1
	if piece.Color == models.PlayerColorBlack {
		forward = -1
	}

	// Forward move is always valid (if within bounds and not blocked)
	forwardPos := from.Offset(0, forward)
	if v.IsValidMove(piece, forwardPos, board) {
		moves = append(moves, forwardPos)
	}

	// Sideways moves only if crossed the river
	if from.HasCrossedRiver(piece.Color) {
		leftPos := from.Offset(-1, 0)
		if v.IsValidMove(piece, leftPos, board) {
			moves = append(moves, leftPos)
		}

		rightPos := from.Offset(1, 0)
		if v.IsValidMove(piece, rightPos, board) {
			moves = append(moves, rightPos)
		}
	}

	return moves
}

// IsValidMove checks if a move is valid for the Soldier.
func (v *SoldierValidator) IsValidMove(piece *Piece, to Position, board *Board) bool {
	from := piece.Position

	// Must be a valid position
	if !to.IsValid() {
		return false
	}

	// Calculate differences
	fileDiff := to.File - from.File
	rankDiff := to.Rank - from.Rank

	// Determine forward direction based on color
	forward := 1
	if piece.Color == models.PlayerColorBlack {
		forward = -1
	}

	// Check if the move is valid
	isForwardMove := fileDiff == 0 && rankDiff == forward
	isSidewaysMove := Abs(fileDiff) == 1 && rankDiff == 0

	if isForwardMove {
		// Forward move is always allowed (for valid destination)
	} else if isSidewaysMove {
		// Sideways move only if crossed the river
		if !from.HasCrossedRiver(piece.Color) {
			return false
		}
	} else {
		// Invalid move pattern
		return false
	}

	// Cannot move backwards
	if piece.Color == models.PlayerColorRed && rankDiff < 0 {
		return false
	}
	if piece.Color == models.PlayerColorBlack && rankDiff > 0 {
		return false
	}

	// Cannot capture own piece
	if board.HasFriendly(to, piece.Color) {
		return false
	}

	return true
}
