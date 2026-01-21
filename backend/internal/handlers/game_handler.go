// Package handlers contains HTTP request handlers.
package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/xiangqi/chinese-chess-backend/internal/services"
	"github.com/xiangqi/chinese-chess-backend/internal/websocket"
)

// GameHandler handles game-related HTTP requests.
type GameHandler struct {
	gameService *services.GameService
	userService *services.UserService
	wsHub       *websocket.Hub
}

// NewGameHandler creates a new GameHandler.
func NewGameHandler(gameService *services.GameService, wsHub *websocket.Hub) *GameHandler {
	return &GameHandler{
		gameService: gameService,
		wsHub:       wsHub,
	}
}

// NewGameHandlerWithUserService creates a new GameHandler with user service.
func NewGameHandlerWithUserService(gameService *services.GameService, userService *services.UserService, wsHub *websocket.Hub) *GameHandler {
	return &GameHandler{
		gameService: gameService,
		userService: userService,
		wsHub:       wsHub,
	}
}

// GetHistory handles getting match history.
func (h *GameHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		respondError(w, http.StatusUnauthorized, "missing_device_id", "Device ID is required")
		return
	}

	// Parse pagination parameters
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}

	pageSize, _ := strconv.Atoi(r.URL.Query().Get("page_size"))
	if pageSize < 1 || pageSize > 50 {
		pageSize = 20
	}

	games, total, err := h.gameService.GetHistory(r.Context(), deviceID, page, pageSize)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get match history")
		return
	}

	// Transform games to response format
	gameResponses := make([]map[string]interface{}, len(games))
	for i, game := range games {
		var opponentID, opponentColor string
		var yourColor string

		if game.RedPlayerID == deviceID {
			opponentID = game.BlackPlayerID
			yourColor = "red"
			opponentColor = "black"
		} else {
			opponentID = game.RedPlayerID
			yourColor = "black"
			opponentColor = "red"
		}

		result := "draw"
		if game.WinnerID != nil {
			if *game.WinnerID == deviceID {
				result = "win"
			} else {
				result = "loss"
			}
		}

		gameResponses[i] = map[string]interface{}{
			"id": game.ID,
			"opponent": map[string]string{
				"id":    opponentID,
				"color": opponentColor,
			},
			"your_color":   yourColor,
			"result":       result,
			"result_type":  game.ResultType,
			"total_moves":  game.TotalMoves,
			"played_at":    game.CreatedAt.Format("2006-01-02T15:04:05Z"),
		}

		if game.CompletedAt != nil {
			duration := int(game.CompletedAt.Sub(game.CreatedAt).Seconds())
			gameResponses[i]["duration_seconds"] = duration
		}
	}

	totalPages := (total + pageSize - 1) / pageSize

	response := map[string]interface{}{
		"games": gameResponses,
		"pagination": map[string]int{
			"page":        page,
			"page_size":   pageSize,
			"total_pages": totalPages,
			"total_count": total,
		},
	}

	respondJSON(w, http.StatusOK, response)
}

// GetGame handles getting a specific game.
func (h *GameHandler) GetGame(w http.ResponseWriter, r *http.Request) {
	gameID := chi.URLParam(r, "gameId")
	if gameID == "" {
		respondError(w, http.StatusBadRequest, "missing_game_id", "Game ID is required")
		return
	}

	game, err := h.gameService.GetGame(r.Context(), gameID)
	if err != nil {
		if errors.Is(err, services.ErrGameNotFound) {
			respondError(w, http.StatusNotFound, "game_not_found", "Game not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get game")
		return
	}

	response := map[string]interface{}{
		"id":            game.ID,
		"red_player_id": game.RedPlayerID,
		"black_player_id": game.BlackPlayerID,
		"status":        game.Status,
		"turn_timeout":  game.TurnTimeoutSeconds,
		"total_moves":   game.TotalMoves,
		"created_at":    game.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}

	if game.WinnerID != nil {
		response["winner_id"] = *game.WinnerID
	}
	if game.ResultType != nil {
		response["result_type"] = *game.ResultType
	}
	if game.CompletedAt != nil {
		response["completed_at"] = game.CompletedAt.Format("2006-01-02T15:04:05Z")
	}

	respondJSON(w, http.StatusOK, response)
}

// GetMoves handles getting moves for a game.
func (h *GameHandler) GetMoves(w http.ResponseWriter, r *http.Request) {
	gameID := chi.URLParam(r, "gameId")
	if gameID == "" {
		respondError(w, http.StatusBadRequest, "missing_game_id", "Game ID is required")
		return
	}

	moves, err := h.gameService.GetMoves(r.Context(), gameID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get moves")
		return
	}

	moveResponses := make([]map[string]interface{}, len(moves))
	for i, move := range moves {
		moveResponses[i] = map[string]interface{}{
			"move_number": move.MoveNumber,
			"player_id":   move.PlayerID,
			"from":        move.FromPosition,
			"to":          move.ToPosition,
			"piece":       move.PieceType,
			"is_check":    move.IsCheck,
			"timestamp":   move.Timestamp.Format("2006-01-02T15:04:05Z"),
		}
		if move.CapturedPiece != nil {
			moveResponses[i]["captured"] = *move.CapturedPiece
		}
	}

	response := map[string]interface{}{
		"game_id": gameID,
		"moves":   moveResponses,
	}

	respondJSON(w, http.StatusOK, response)
}

// GetGameWithMoves handles getting a game with all its moves in one request.
func (h *GameHandler) GetGameWithMoves(w http.ResponseWriter, r *http.Request) {
	gameID := chi.URLParam(r, "gameId")
	if gameID == "" {
		respondError(w, http.StatusBadRequest, "missing_game_id", "Game ID is required")
		return
	}

	// Get game
	game, err := h.gameService.GetGame(r.Context(), gameID)
	if err != nil {
		if errors.Is(err, services.ErrGameNotFound) {
			respondError(w, http.StatusNotFound, "game_not_found", "Game not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get game")
		return
	}

	// Get moves
	moves, err := h.gameService.GetMoves(r.Context(), gameID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get moves")
		return
	}

	// Build move responses
	moveResponses := make([]map[string]interface{}, len(moves))
	for i, move := range moves {
		moveResponses[i] = map[string]interface{}{
			"move_number": move.MoveNumber,
			"player_id":   move.PlayerID,
			"from":        move.FromPosition,
			"to":          move.ToPosition,
			"piece":       move.PieceType,
			"is_check":    move.IsCheck,
			"timestamp":   move.Timestamp.Format("2006-01-02T15:04:05Z"),
		}
		if move.CapturedPiece != nil {
			moveResponses[i]["captured"] = *move.CapturedPiece
		}
	}

	// Build response
	response := map[string]interface{}{
		"id":              game.ID,
		"red_player_id":   game.RedPlayerID,
		"black_player_id": game.BlackPlayerID,
		"status":          game.Status,
		"turn_timeout":    game.TurnTimeoutSeconds,
		"total_moves":     game.TotalMoves,
		"created_at":      game.CreatedAt.Format("2006-01-02T15:04:05Z"),
		"moves":           moveResponses,
		"red_rollbacks_remaining":   game.RedRollbacksRemaining,
		"black_rollbacks_remaining": game.BlackRollbacksRemaining,
	}

	if game.WinnerID != nil {
		response["winner_id"] = *game.WinnerID
	}
	if game.ResultType != nil {
		response["result_type"] = *game.ResultType
	}
	if game.CompletedAt != nil {
		response["completed_at"] = game.CompletedAt.Format("2006-01-02T15:04:05Z")
	}

	respondJSON(w, http.StatusOK, response)
}

// GetUserStats handles getting user statistics.
func (h *GameHandler) GetUserStats(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "userId")
	if deviceID == "" {
		// Try to get from header as fallback
		deviceID = r.Header.Get("X-Device-ID")
	}

	if deviceID == "" {
		respondError(w, http.StatusBadRequest, "missing_user_id", "User ID is required")
		return
	}

	// Check if user service is available
	if h.userService == nil {
		respondError(w, http.StatusInternalServerError, "service_unavailable", "User service not available")
		return
	}

	user, err := h.userService.GetByID(r.Context(), deviceID)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			respondError(w, http.StatusNotFound, "user_not_found", "User not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get user stats")
		return
	}

	stats := user.Stats()
	response := map[string]interface{}{
		"user_id": deviceID,
		"stats": map[string]interface{}{
			"total_games":    stats.TotalGames,
			"wins":           stats.Wins,
			"losses":         stats.Losses,
			"draws":          stats.Draws,
			"win_percentage": stats.WinPercentage,
		},
	}

	respondJSON(w, http.StatusOK, response)
}

// GetActiveGames returns active games for a user.
func (h *GameHandler) GetActiveGames(w http.ResponseWriter, r *http.Request) {
	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		respondError(w, http.StatusUnauthorized, "missing_device_id", "Device ID is required")
		return
	}

	games, err := h.gameService.GetActiveGames(r.Context(), deviceID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get active games")
		return
	}

	gameResponses := make([]map[string]interface{}, len(games))
	for i, game := range games {
		var opponentID, yourColor string
		if game.RedPlayerID == deviceID {
			opponentID = game.BlackPlayerID
			yourColor = "red"
		} else {
			opponentID = game.RedPlayerID
			yourColor = "black"
		}

		gameResponses[i] = map[string]interface{}{
			"id":          game.ID,
			"opponent_id": opponentID,
			"your_color":  yourColor,
			"total_moves": game.TotalMoves,
			"created_at":  game.CreatedAt.Format("2006-01-02T15:04:05Z"),
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"games": gameResponses,
	})
}
