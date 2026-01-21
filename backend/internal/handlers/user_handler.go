// Package handlers contains HTTP request handlers.
package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/xiangqi/chinese-chess-backend/internal/services"
)

// UserHandler handles user-related HTTP requests.
type UserHandler struct {
	userService *services.UserService
}

// NewUserHandler creates a new UserHandler.
func NewUserHandler(userService *services.UserService) *UserHandler {
	return &UserHandler{userService: userService}
}

// RegisterRequest represents a user registration request.
type RegisterRequest struct {
	DeviceID    string `json:"device_id"`
	DisplayName string `json:"display_name"`
	Platform    string `json:"platform"`
	AppVersion  string `json:"app_version"`
}

// UserResponse represents a user in API responses.
type UserResponse struct {
	ID          string        `json:"id"`
	DisplayName string        `json:"display_name"`
	Stats       StatsResponse `json:"stats"`
	CreatedAt   string        `json:"created_at"`
	UpdatedAt   string        `json:"updated_at,omitempty"`
}

// StatsResponse represents user stats in API responses.
type StatsResponse struct {
	TotalGames    int     `json:"total_games"`
	Wins          int     `json:"wins"`
	Losses        int     `json:"losses"`
	Draws         int     `json:"draws"`
	WinPercentage float64 `json:"win_percentage"`
}

// Register handles user registration.
func (h *UserHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
		return
	}

	if req.DeviceID == "" {
		respondError(w, http.StatusBadRequest, "missing_device_id", "Device ID is required")
		return
	}

	if req.DisplayName == "" {
		respondError(w, http.StatusBadRequest, "missing_display_name", "Display name is required")
		return
	}

	user, err := h.userService.Register(r.Context(), req.DeviceID, req.DisplayName)
	if err != nil {
		if errors.Is(err, services.ErrDisplayNameTooShort) ||
			errors.Is(err, services.ErrDisplayNameTooLong) ||
			errors.Is(err, services.ErrDisplayNameInvalidChars) ||
			errors.Is(err, services.ErrDisplayNameReserved) {
			respondError(w, http.StatusBadRequest, "invalid_display_name", err.Error())
			return
		}
		respondError(w, http.StatusInternalServerError, "registration_failed", "Failed to register user")
		return
	}

	stats := user.Stats()
	response := UserResponse{
		ID:          user.ID,
		DisplayName: user.DisplayName,
		Stats: StatsResponse{
			TotalGames:    stats.TotalGames,
			Wins:          stats.Wins,
			Losses:        stats.Losses,
			Draws:         stats.Draws,
			WinPercentage: stats.WinPercentage,
		},
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt: user.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}

	respondJSON(w, http.StatusCreated, response)
}

// GetProfile handles getting a user profile.
func (h *UserHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "deviceId")
	if deviceID == "" {
		respondError(w, http.StatusBadRequest, "missing_device_id", "Device ID is required")
		return
	}

	user, err := h.userService.GetByID(r.Context(), deviceID)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			respondError(w, http.StatusNotFound, "user_not_found", "User not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "fetch_failed", "Failed to get user")
		return
	}

	stats := user.Stats()
	response := UserResponse{
		ID:          user.ID,
		DisplayName: user.DisplayName,
		Stats: StatsResponse{
			TotalGames:    stats.TotalGames,
			Wins:          stats.Wins,
			Losses:        stats.Losses,
			Draws:         stats.Draws,
			WinPercentage: stats.WinPercentage,
		},
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt: user.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}

	respondJSON(w, http.StatusOK, response)
}

// UpdateProfileRequest represents a profile update request.
type UpdateProfileRequest struct {
	DisplayName string `json:"display_name"`
}

// UpdateProfile handles updating a user profile.
func (h *UserHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "deviceId")
	if deviceID == "" {
		respondError(w, http.StatusBadRequest, "missing_device_id", "Device ID is required")
		return
	}

	var req UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
		return
	}

	user, err := h.userService.UpdateDisplayName(r.Context(), deviceID, req.DisplayName)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			respondError(w, http.StatusNotFound, "user_not_found", "User not found")
			return
		}
		if errors.Is(err, services.ErrDisplayNameTooShort) ||
			errors.Is(err, services.ErrDisplayNameTooLong) ||
			errors.Is(err, services.ErrDisplayNameInvalidChars) ||
			errors.Is(err, services.ErrDisplayNameReserved) {
			respondError(w, http.StatusBadRequest, "invalid_display_name", err.Error())
			return
		}
		respondError(w, http.StatusInternalServerError, "update_failed", "Failed to update profile")
		return
	}

	response := map[string]interface{}{
		"id":           user.ID,
		"display_name": user.DisplayName,
		"updated_at":   user.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}

	respondJSON(w, http.StatusOK, response)
}

// Helper functions for JSON responses

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
