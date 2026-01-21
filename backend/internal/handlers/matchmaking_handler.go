// Package handlers contains HTTP request handlers.
package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/services"
)

// MatchmakingHandler handles matchmaking-related HTTP requests.
type MatchmakingHandler struct {
	matchmakingService *services.MatchmakingService
}

// NewMatchmakingHandler creates a new MatchmakingHandler.
func NewMatchmakingHandler(matchmakingService *services.MatchmakingService) *MatchmakingHandler {
	return &MatchmakingHandler{matchmakingService: matchmakingService}
}

// JoinQueueRequest represents a request to join the matchmaking queue.
type JoinQueueRequest struct {
	Settings struct {
		TurnTimeout    int     `json:"turn_timeout"`
		PreferredColor *string `json:"preferred_color"`
	} `json:"settings"`
}

// JoinQueue handles joining the matchmaking queue.
func (h *MatchmakingHandler) JoinQueue(w http.ResponseWriter, r *http.Request) {
	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		respondError(w, http.StatusUnauthorized, "missing_device_id", "Device ID is required")
		return
	}

	var req JoinQueueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
		return
	}

	// Default timeout to 5 minutes if not specified
	if req.Settings.TurnTimeout == 0 {
		req.Settings.TurnTimeout = 300
	}

	entry := &models.MatchmakingEntry{
		DeviceID:    deviceID,
		DisplayName: "Player", // TODO: Get from user service
		TurnTimeout: req.Settings.TurnTimeout,
	}

	status, err := h.matchmakingService.JoinQueue(r.Context(), entry)
	if err != nil {
		if errors.Is(err, services.ErrAlreadyInQueue) {
			respondError(w, http.StatusConflict, "already_in_queue", "You are already in the matchmaking queue")
			return
		}
		respondError(w, http.StatusInternalServerError, "join_failed", "Failed to join matchmaking queue")
		return
	}

	response := map[string]interface{}{
		"status":                 status.Status,
		"position":               status.Position,
		"estimated_wait_seconds": status.EstimatedWaitSeconds,
	}

	if status.Status == services.StatusMatched {
		response["game_id"] = status.GameID
		response["opponent_name"] = status.OpponentName
		response["your_color"] = status.YourColor
	}

	respondJSON(w, http.StatusOK, response)
}

// LeaveQueue handles leaving the matchmaking queue.
func (h *MatchmakingHandler) LeaveQueue(w http.ResponseWriter, r *http.Request) {
	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		respondError(w, http.StatusUnauthorized, "missing_device_id", "Device ID is required")
		return
	}

	if err := h.matchmakingService.LeaveQueue(r.Context(), deviceID); err != nil {
		respondError(w, http.StatusInternalServerError, "leave_failed", "Failed to leave matchmaking queue")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

// GetStatus handles getting the current matchmaking status.
func (h *MatchmakingHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		respondError(w, http.StatusUnauthorized, "missing_device_id", "Device ID is required")
		return
	}

	status, err := h.matchmakingService.GetStatus(r.Context(), deviceID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "status_failed", "Failed to get matchmaking status")
		return
	}

	response := map[string]interface{}{
		"status": status.Status,
	}

	if status.Status == services.StatusWaiting {
		response["position"] = status.Position
		response["estimated_wait_seconds"] = status.EstimatedWaitSeconds
	} else if status.Status == services.StatusMatched {
		response["game_id"] = status.GameID
		response["opponent_name"] = status.OpponentName
		response["your_color"] = status.YourColor
	}

	respondJSON(w, http.StatusOK, response)
}
