// Package handlers contains HTTP request handlers.
package handlers

import (
	"net/http"
	"os"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"

	"github.com/xiangqi/chinese-chess-backend/internal/services"
	ws "github.com/xiangqi/chinese-chess-backend/internal/websocket"
)

// AllowedOrigins contains the list of allowed WebSocket origins.
// Configure via environment variable XIANGQI_ALLOWED_ORIGINS (comma-separated).
var AllowedOrigins = []string{
	"https://xiangqi-app.com",
	"https://www.xiangqi-app.com",
	"https://api.xiangqi-app.com",
	"capacitor://localhost", // iOS app
	"ionic://localhost",     // Ionic app
}

// isDevelopment checks if running in development mode.
func isDevelopment() bool {
	env := os.Getenv("XIANGQI_ENVIRONMENT")
	return env == "" || env == "development"
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")

		// In development, allow localhost origins
		if isDevelopment() {
			if origin == "" ||
				strings.HasPrefix(origin, "http://localhost") ||
				strings.HasPrefix(origin, "http://127.0.0.1") ||
				strings.HasPrefix(origin, "capacitor://") ||
				strings.HasPrefix(origin, "ionic://") {
				return true
			}
		}

		// Check against allowed origins
		for _, allowed := range AllowedOrigins {
			if origin == allowed {
				return true
			}
		}

		// Log rejected origins for monitoring
		log.Warn().
			Str("origin", origin).
			Str("remote_addr", r.RemoteAddr).
			Msg("WebSocket connection rejected: origin not allowed")

		return false
	},
}

// WebSocketHandler handles WebSocket connections.
type WebSocketHandler struct {
	hub         *ws.Hub
	gameService *services.GameService
}

// NewWebSocketHandler creates a new WebSocketHandler.
func NewWebSocketHandler(hub *ws.Hub, gameService *services.GameService) *WebSocketHandler {
	return &WebSocketHandler{
		hub:         hub,
		gameService: gameService,
	}
}

// HandleConnection handles WebSocket connection upgrades.
func (h *WebSocketHandler) HandleConnection(w http.ResponseWriter, r *http.Request) {
	gameID := chi.URLParam(r, "gameId")
	if gameID == "" {
		http.Error(w, "Game ID is required", http.StatusBadRequest)
		return
	}

	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		// Also check query parameter for WebSocket connections
		deviceID = r.URL.Query().Get("device_id")
	}
	if deviceID == "" {
		http.Error(w, "Device ID is required", http.StatusUnauthorized)
		return
	}

	// Verify game exists
	game, err := h.gameService.GetGame(r.Context(), gameID)
	if err != nil {
		http.Error(w, "Game not found", http.StatusNotFound)
		return
	}

	// Verify player is part of the game
	if game.RedPlayerID != deviceID && game.BlackPlayerID != deviceID {
		http.Error(w, "You are not a participant in this game", http.StatusForbidden)
		return
	}

	// Upgrade connection to WebSocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to upgrade WebSocket connection")
		return
	}

	// Create client and register with hub
	client := ws.NewClient(h.hub, conn, gameID, deviceID)
	h.hub.Register(client)

	// Start client read/write goroutines
	go client.WritePump()
	go client.ReadPump()

	log.Info().
		Str("game_id", gameID).
		Str("device_id", deviceID).
		Msg("WebSocket connection established")
}
