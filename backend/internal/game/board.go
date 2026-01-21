// Package game implements the Xiangqi (Chinese Chess) game logic.
package game

import (
	"fmt"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
)

// Board represents a Xiangqi board with 10 rows and 9 columns.
// The board is indexed as [rank][file] where:
// - rank 0-4 is the Red side, rank 5-9 is the Black side
// - file 0-8 represents columns a-i
type Board struct {
	squares [10][9]*Piece
}

// Piece represents a piece on the board.
type Piece struct {
	Type     models.PieceType
	Color    models.PlayerColor
	Position Position
}

// Position represents a position on the board.
type Position struct {
	File int // 0-8 (columns a-i)
	Rank int // 0-9 (rows)
}

// Constants for board dimensions.
const (
	FileCount = 9
	RankCount = 10
)

// NewBoard creates a new empty board.
func NewBoard() *Board {
	return &Board{}
}

// NewInitialBoard creates a board with the standard starting position.
func NewInitialBoard() *Board {
	b := NewBoard()

	// Place Red pieces (ranks 0-3)
	// Back row (rank 0)
	b.Place(&Piece{Type: models.PieceTypeChariot, Color: models.PlayerColorRed, Position: Position{0, 0}})
	b.Place(&Piece{Type: models.PieceTypeHorse, Color: models.PlayerColorRed, Position: Position{1, 0}})
	b.Place(&Piece{Type: models.PieceTypeElephant, Color: models.PlayerColorRed, Position: Position{2, 0}})
	b.Place(&Piece{Type: models.PieceTypeAdvisor, Color: models.PlayerColorRed, Position: Position{3, 0}})
	b.Place(&Piece{Type: models.PieceTypeGeneral, Color: models.PlayerColorRed, Position: Position{4, 0}})
	b.Place(&Piece{Type: models.PieceTypeAdvisor, Color: models.PlayerColorRed, Position: Position{5, 0}})
	b.Place(&Piece{Type: models.PieceTypeElephant, Color: models.PlayerColorRed, Position: Position{6, 0}})
	b.Place(&Piece{Type: models.PieceTypeHorse, Color: models.PlayerColorRed, Position: Position{7, 0}})
	b.Place(&Piece{Type: models.PieceTypeChariot, Color: models.PlayerColorRed, Position: Position{8, 0}})

	// Cannons (rank 2)
	b.Place(&Piece{Type: models.PieceTypeCannon, Color: models.PlayerColorRed, Position: Position{1, 2}})
	b.Place(&Piece{Type: models.PieceTypeCannon, Color: models.PlayerColorRed, Position: Position{7, 2}})

	// Soldiers (rank 3)
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorRed, Position: Position{0, 3}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorRed, Position: Position{2, 3}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorRed, Position: Position{4, 3}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorRed, Position: Position{6, 3}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorRed, Position: Position{8, 3}})

	// Place Black pieces (ranks 6-9)
	// Back row (rank 9)
	b.Place(&Piece{Type: models.PieceTypeChariot, Color: models.PlayerColorBlack, Position: Position{0, 9}})
	b.Place(&Piece{Type: models.PieceTypeHorse, Color: models.PlayerColorBlack, Position: Position{1, 9}})
	b.Place(&Piece{Type: models.PieceTypeElephant, Color: models.PlayerColorBlack, Position: Position{2, 9}})
	b.Place(&Piece{Type: models.PieceTypeAdvisor, Color: models.PlayerColorBlack, Position: Position{3, 9}})
	b.Place(&Piece{Type: models.PieceTypeGeneral, Color: models.PlayerColorBlack, Position: Position{4, 9}})
	b.Place(&Piece{Type: models.PieceTypeAdvisor, Color: models.PlayerColorBlack, Position: Position{5, 9}})
	b.Place(&Piece{Type: models.PieceTypeElephant, Color: models.PlayerColorBlack, Position: Position{6, 9}})
	b.Place(&Piece{Type: models.PieceTypeHorse, Color: models.PlayerColorBlack, Position: Position{7, 9}})
	b.Place(&Piece{Type: models.PieceTypeChariot, Color: models.PlayerColorBlack, Position: Position{8, 9}})

	// Cannons (rank 7)
	b.Place(&Piece{Type: models.PieceTypeCannon, Color: models.PlayerColorBlack, Position: Position{1, 7}})
	b.Place(&Piece{Type: models.PieceTypeCannon, Color: models.PlayerColorBlack, Position: Position{7, 7}})

	// Soldiers (rank 6)
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorBlack, Position: Position{0, 6}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorBlack, Position: Position{2, 6}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorBlack, Position: Position{4, 6}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorBlack, Position: Position{6, 6}})
	b.Place(&Piece{Type: models.PieceTypeSoldier, Color: models.PlayerColorBlack, Position: Position{8, 6}})

	return b
}

// At returns the piece at the given position, or nil if empty.
func (b *Board) At(pos Position) *Piece {
	if !pos.IsValid() {
		return nil
	}
	return b.squares[pos.Rank][pos.File]
}

// Place places a piece on the board.
func (b *Board) Place(piece *Piece) {
	if piece.Position.IsValid() {
		b.squares[piece.Position.Rank][piece.Position.File] = piece
	}
}

// Remove removes the piece at the given position.
func (b *Board) Remove(pos Position) *Piece {
	if !pos.IsValid() {
		return nil
	}
	piece := b.squares[pos.Rank][pos.File]
	b.squares[pos.Rank][pos.File] = nil
	return piece
}

// Move moves a piece from one position to another.
// Returns the captured piece, if any.
func (b *Board) Move(from, to Position) *Piece {
	piece := b.Remove(from)
	if piece == nil {
		return nil
	}
	captured := b.Remove(to)
	piece.Position = to
	b.Place(piece)
	return captured
}

// IsEmpty returns true if the position is empty.
func (b *Board) IsEmpty(pos Position) bool {
	return b.At(pos) == nil
}

// HasPiece returns true if there is a piece at the position.
func (b *Board) HasPiece(pos Position) bool {
	return b.At(pos) != nil
}

// HasEnemy returns true if there is an enemy piece at the position.
func (b *Board) HasEnemy(pos Position, color models.PlayerColor) bool {
	piece := b.At(pos)
	return piece != nil && piece.Color != color
}

// HasFriendly returns true if there is a friendly piece at the position.
func (b *Board) HasFriendly(pos Position, color models.PlayerColor) bool {
	piece := b.At(pos)
	return piece != nil && piece.Color == color
}

// GetPieces returns all pieces of the given color.
func (b *Board) GetPieces(color models.PlayerColor) []*Piece {
	var pieces []*Piece
	for rank := 0; rank < RankCount; rank++ {
		for file := 0; file < FileCount; file++ {
			if piece := b.squares[rank][file]; piece != nil && piece.Color == color {
				pieces = append(pieces, piece)
			}
		}
	}
	return pieces
}

// GetGeneral returns the general of the given color.
func (b *Board) GetGeneral(color models.PlayerColor) *Piece {
	for rank := 0; rank < RankCount; rank++ {
		for file := 0; file < FileCount; file++ {
			if piece := b.squares[rank][file]; piece != nil && piece.Color == color && piece.Type == models.PieceTypeGeneral {
				return piece
			}
		}
	}
	return nil
}

// Copy returns a deep copy of the board.
func (b *Board) Copy() *Board {
	newBoard := NewBoard()
	for rank := 0; rank < RankCount; rank++ {
		for file := 0; file < FileCount; file++ {
			if piece := b.squares[rank][file]; piece != nil {
				newPiece := &Piece{
					Type:     piece.Type,
					Color:    piece.Color,
					Position: piece.Position,
				}
				newBoard.squares[rank][file] = newPiece
			}
		}
	}
	return newBoard
}

// String returns a string representation of the board.
func (b *Board) String() string {
	var result string
	for rank := RankCount - 1; rank >= 0; rank-- {
		result += fmt.Sprintf("%d ", rank)
		for file := 0; file < FileCount; file++ {
			if piece := b.squares[rank][file]; piece != nil {
				result += pieceChar(piece) + " "
			} else {
				result += ". "
			}
		}
		result += "\n"
	}
	result += "  a b c d e f g h i\n"
	return result
}

// pieceChar returns the Chinese character for a piece.
func pieceChar(p *Piece) string {
	switch p.Type {
	case models.PieceTypeGeneral:
		if p.Color == models.PlayerColorRed {
			return "帅"
		}
		return "将"
	case models.PieceTypeAdvisor:
		if p.Color == models.PlayerColorRed {
			return "仕"
		}
		return "士"
	case models.PieceTypeElephant:
		if p.Color == models.PlayerColorRed {
			return "相"
		}
		return "象"
	case models.PieceTypeHorse:
		return "马"
	case models.PieceTypeChariot:
		return "车"
	case models.PieceTypeCannon:
		return "炮"
	case models.PieceTypeSoldier:
		if p.Color == models.PlayerColorRed {
			return "兵"
		}
		return "卒"
	}
	return "?"
}

// Position methods

// IsValid returns true if the position is within the board bounds.
func (p Position) IsValid() bool {
	return p.File >= 0 && p.File < FileCount && p.Rank >= 0 && p.Rank < RankCount
}

// IsInRedPalace returns true if the position is within the Red palace.
func (p Position) IsInRedPalace() bool {
	return p.File >= 3 && p.File <= 5 && p.Rank >= 0 && p.Rank <= 2
}

// IsInBlackPalace returns true if the position is within the Black palace.
func (p Position) IsInBlackPalace() bool {
	return p.File >= 3 && p.File <= 5 && p.Rank >= 7 && p.Rank <= 9
}

// IsInPalace returns true if the position is within the palace for the given color.
func (p Position) IsInPalace(color models.PlayerColor) bool {
	if color == models.PlayerColorRed {
		return p.IsInRedPalace()
	}
	return p.IsInBlackPalace()
}

// IsOnRedSide returns true if the position is on the Red side of the river.
func (p Position) IsOnRedSide() bool {
	return p.Rank >= 0 && p.Rank <= 4
}

// IsOnBlackSide returns true if the position is on the Black side of the river.
func (p Position) IsOnBlackSide() bool {
	return p.Rank >= 5 && p.Rank <= 9
}

// HasCrossedRiver returns true if the position has crossed the river for the given color.
func (p Position) HasCrossedRiver(color models.PlayerColor) bool {
	if color == models.PlayerColorRed {
		return p.IsOnBlackSide()
	}
	return p.IsOnRedSide()
}

// Notation returns the algebraic notation for the position (e.g., "e4").
func (p Position) Notation() string {
	files := "abcdefghi"
	if p.File < 0 || p.File >= 9 {
		return "??"
	}
	return fmt.Sprintf("%c%d", files[p.File], p.Rank)
}

// Offset returns a new position offset by the given values.
func (p Position) Offset(fileOffset, rankOffset int) Position {
	return Position{
		File: p.File + fileOffset,
		Rank: p.Rank + rankOffset,
	}
}

// Abs returns the absolute value of an integer.
func Abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
