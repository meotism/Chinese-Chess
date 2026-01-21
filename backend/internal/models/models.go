// Package models contains the domain models for the Chinese Chess application.
package models

import (
	"time"
)

// User represents a player in the system.
type User struct {
	ID          string    `json:"id" db:"id"`                     // Device ID
	DisplayName string    `json:"display_name" db:"display_name"` // User's display name
	TotalGames  int       `json:"total_games" db:"total_games"`   // Total games played
	Wins        int       `json:"wins" db:"wins"`                 // Games won
	Losses      int       `json:"losses" db:"losses"`             // Games lost
	Draws       int       `json:"draws" db:"draws"`               // Games drawn
	CreatedAt   time.Time `json:"created_at" db:"created_at"`     // When user was created
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`     // When user was last updated
}

// UserStats returns the user's gameplay statistics.
type UserStats struct {
	TotalGames    int     `json:"total_games"`
	Wins          int     `json:"wins"`
	Losses        int     `json:"losses"`
	Draws         int     `json:"draws"`
	WinPercentage float64 `json:"win_percentage"`
}

// Stats returns the user's stats.
func (u *User) Stats() UserStats {
	var winPct float64
	if u.TotalGames > 0 {
		winPct = float64(u.Wins) / float64(u.TotalGames) * 100
	}
	return UserStats{
		TotalGames:    u.TotalGames,
		Wins:          u.Wins,
		Losses:        u.Losses,
		Draws:         u.Draws,
		WinPercentage: winPct,
	}
}

// GameStatus represents the status of a game.
type GameStatus string

const (
	GameStatusActive    GameStatus = "active"
	GameStatusCompleted GameStatus = "completed"
	GameStatusAbandoned GameStatus = "abandoned"
)

// ResultType represents how a game ended.
type ResultType string

const (
	ResultTypeCheckmate   ResultType = "checkmate"
	ResultTypeTimeout     ResultType = "timeout"
	ResultTypeResignation ResultType = "resignation"
	ResultTypeAbandonment ResultType = "abandonment"
	ResultTypeDraw        ResultType = "draw"
	ResultTypeStalemate   ResultType = "stalemate"
)

// Game represents a game record.
type Game struct {
	ID                     string      `json:"id" db:"id"`
	RedPlayerID            string      `json:"red_player_id" db:"red_player_id"`
	BlackPlayerID          string      `json:"black_player_id" db:"black_player_id"`
	Status                 GameStatus  `json:"status" db:"status"`
	WinnerID               *string     `json:"winner_id,omitempty" db:"winner_id"`
	ResultType             *ResultType `json:"result_type,omitempty" db:"result_type"`
	TurnTimeoutSeconds     int         `json:"turn_timeout_seconds" db:"turn_timeout_seconds"`
	RedRollbacksRemaining  int         `json:"red_rollbacks_remaining" db:"red_rollbacks_remaining"`
	BlackRollbacksRemaining int        `json:"black_rollbacks_remaining" db:"black_rollbacks_remaining"`
	TotalMoves             int         `json:"total_moves" db:"total_moves"`
	CreatedAt              time.Time   `json:"created_at" db:"created_at"`
	CompletedAt            *time.Time  `json:"completed_at,omitempty" db:"completed_at"`
}

// PlayerColor represents the color/side of a player.
type PlayerColor string

const (
	PlayerColorRed   PlayerColor = "red"
	PlayerColorBlack PlayerColor = "black"
)

// PieceType represents the type of a chess piece.
type PieceType string

const (
	PieceTypeGeneral  PieceType = "general"
	PieceTypeAdvisor  PieceType = "advisor"
	PieceTypeElephant PieceType = "elephant"
	PieceTypeHorse    PieceType = "horse"
	PieceTypeChariot  PieceType = "chariot"
	PieceTypeCannon   PieceType = "cannon"
	PieceTypeSoldier  PieceType = "soldier"
)

// Move represents a move in a game.
type Move struct {
	ID            int64      `json:"id" db:"id"`
	GameID        string     `json:"game_id" db:"game_id"`
	MoveNumber    int        `json:"move_number" db:"move_number"`
	PlayerID      string     `json:"player_id" db:"player_id"`
	FromPosition  string     `json:"from_position" db:"from_position"`
	ToPosition    string     `json:"to_position" db:"to_position"`
	PieceType     PieceType  `json:"piece_type" db:"piece_type"`
	CapturedPiece *PieceType `json:"captured_piece,omitempty" db:"captured_piece"`
	IsCheck       bool       `json:"is_check" db:"is_check"`
	Timestamp     time.Time  `json:"timestamp" db:"timestamp"`
}

// RollbackStatus represents the status of a rollback request.
type RollbackStatus string

const (
	RollbackStatusPending  RollbackStatus = "pending"
	RollbackStatusAccepted RollbackStatus = "accepted"
	RollbackStatusDeclined RollbackStatus = "declined"
	RollbackStatusExpired  RollbackStatus = "expired"
)

// Rollback represents a rollback request.
type Rollback struct {
	ID                 int64          `json:"id" db:"id"`
	GameID             string         `json:"game_id" db:"game_id"`
	RequestingPlayerID string         `json:"requesting_player_id" db:"requesting_player_id"`
	MoveNumberReverted int            `json:"move_number_reverted" db:"move_number_reverted"`
	Status             RollbackStatus `json:"status" db:"status"`
	Timestamp          time.Time      `json:"timestamp" db:"timestamp"`
}

// Position represents a position on the board.
type Position struct {
	File int `json:"file"` // 0-8 (columns a-i)
	Rank int `json:"rank"` // 0-9 (rows)
}

// Piece represents a piece on the board.
type Piece struct {
	Type     PieceType   `json:"type"`
	Color    PlayerColor `json:"color"`
	Position Position    `json:"position"`
}

// GameState represents the current state of a game.
type GameState struct {
	Board           [10][9]*Piece `json:"board"`
	CurrentTurn     PlayerColor   `json:"current_turn"`
	IsCheck         bool          `json:"is_check"`
	MoveHistory     []Move        `json:"move_history"`
	CapturedByRed   []Piece       `json:"captured_by_red"`
	CapturedByBlack []Piece       `json:"captured_by_black"`
}

// MatchmakingEntry represents a player in the matchmaking queue.
type MatchmakingEntry struct {
	DeviceID    string    `json:"device_id"`
	DisplayName string    `json:"display_name"`
	TurnTimeout int       `json:"turn_timeout"`
	JoinedAt    time.Time `json:"joined_at"`
}
