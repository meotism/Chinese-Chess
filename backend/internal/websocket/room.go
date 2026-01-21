// Package websocket handles WebSocket connections for real-time gameplay.
package websocket

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/rs/zerolog/log"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/services"
)

// GameRoom represents an active game session with its state and connected players.
type GameRoom struct {
	GameID       string
	Game         *models.Game
	Hub          *Hub
	GameService  *services.GameService
	Timer        *GameTimer
	TimerManager *TimerManager

	// Connected players
	RedPlayer   *Client
	BlackPlayer *Client

	// Game state
	CurrentTurn     models.PlayerColor
	MoveCount       int
	GameState       *models.GameState
	IsGameOver      bool

	// Rollback state
	PendingRollback    *RollbackRequest
	RollbackTimeout    *time.Timer

	// Disconnection handling
	DisconnectedPlayer string
	DisconnectTimer    *time.Timer
	GracePeriod        time.Duration

	mu sync.RWMutex
}

// RollbackRequest represents a pending rollback request.
type RollbackRequest struct {
	RequestingPlayerID string
	MoveNumberToRevert int
	RequestedAt        time.Time
	TimeoutSeconds     int
}

// RoomManager manages all active game rooms.
type RoomManager struct {
	rooms        map[string]*GameRoom
	timerManager *TimerManager
	mu           sync.RWMutex
}

// NewRoomManager creates a new RoomManager.
func NewRoomManager() *RoomManager {
	return &RoomManager{
		rooms:        make(map[string]*GameRoom),
		timerManager: NewTimerManager(),
	}
}

// CreateRoom creates a new game room.
func (m *RoomManager) CreateRoom(gameID string, game *models.Game, hub *Hub, gameService *services.GameService) *GameRoom {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Create timer for this game
	timer := m.timerManager.CreateTimer(gameID, hub, game.TurnTimeoutSeconds)

	room := &GameRoom{
		GameID:       gameID,
		Game:         game,
		Hub:          hub,
		GameService:  gameService,
		Timer:        timer,
		TimerManager: m.timerManager,
		CurrentTurn:  models.PlayerColorRed,
		MoveCount:    0,
		IsGameOver:   false,
		GracePeriod:  60 * time.Second,
	}

	m.rooms[gameID] = room

	log.Info().
		Str("game_id", gameID).
		Str("red_player", game.RedPlayerID).
		Str("black_player", game.BlackPlayerID).
		Msg("Game room created")

	return room
}

// GetRoom retrieves a game room by ID.
func (m *RoomManager) GetRoom(gameID string) *GameRoom {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.rooms[gameID]
}

// RemoveRoom removes a game room.
func (m *RoomManager) RemoveRoom(gameID string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if room, ok := m.rooms[gameID]; ok {
		room.Cleanup()
		delete(m.rooms, gameID)
	}

	m.timerManager.RemoveTimer(gameID)

	log.Info().Str("game_id", gameID).Msg("Game room removed")
}

// Cleanup cleans up room resources.
func (r *GameRoom) Cleanup() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.Timer != nil {
		r.Timer.Stop()
	}

	if r.RollbackTimeout != nil {
		r.RollbackTimeout.Stop()
	}

	if r.DisconnectTimer != nil {
		r.DisconnectTimer.Stop()
	}
}

// JoinPlayer adds a player to the room.
func (r *GameRoom) JoinPlayer(client *Client) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if client.DeviceID == r.Game.RedPlayerID {
		r.RedPlayer = client
		log.Info().Str("game_id", r.GameID).Str("player", "red").Msg("Red player joined")
	} else if client.DeviceID == r.Game.BlackPlayerID {
		r.BlackPlayer = client
		log.Info().Str("game_id", r.GameID).Str("player", "black").Msg("Black player joined")
	} else {
		log.Warn().
			Str("game_id", r.GameID).
			Str("device_id", client.DeviceID).
			Msg("Unknown player tried to join")
		return services.ErrPlayerNotInGame
	}

	// Check if player was disconnected
	if r.DisconnectedPlayer == client.DeviceID {
		r.handleReconnection(client)
	}

	// Start timer if both players are connected
	if r.RedPlayer != nil && r.BlackPlayer != nil && !r.Timer.IsRunning {
		r.Timer.Start()
		r.sendGameState()
	}

	return nil
}

// LeavePlayer removes a player from the room.
func (r *GameRoom) LeavePlayer(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	var leavingPlayerColor string

	if r.RedPlayer == client {
		r.RedPlayer = nil
		r.DisconnectedPlayer = client.DeviceID
		leavingPlayerColor = "red"
	} else if r.BlackPlayer == client {
		r.BlackPlayer = nil
		r.DisconnectedPlayer = client.DeviceID
		leavingPlayerColor = "black"
	}

	if leavingPlayerColor != "" {
		r.handleDisconnection(client.DeviceID, leavingPlayerColor)
	}
}

// handleDisconnection handles a player disconnection.
func (r *GameRoom) handleDisconnection(deviceID string, color string) {
	log.Info().
		Str("game_id", r.GameID).
		Str("player_color", color).
		Msg("Player disconnected")

	// Pause the timer
	r.Timer.Pause()

	// Notify the other player
	r.broadcastConnectionStatus("opponent_disconnected", deviceID)

	// Start grace period timer
	r.DisconnectTimer = time.AfterFunc(r.GracePeriod, func() {
		r.handleAbandonmentTimeout(deviceID)
	})
}

// handleReconnection handles a player reconnecting.
func (r *GameRoom) handleReconnection(client *Client) {
	log.Info().
		Str("game_id", r.GameID).
		Str("device_id", client.DeviceID).
		Msg("Player reconnected")

	// Cancel the disconnect timer
	if r.DisconnectTimer != nil {
		r.DisconnectTimer.Stop()
		r.DisconnectTimer = nil
	}

	r.DisconnectedPlayer = ""

	// Resume the timer
	r.Timer.Resume()

	// Notify the other player
	r.broadcastConnectionStatus("opponent_reconnected", client.DeviceID)
}

// handleAbandonmentTimeout is called when the grace period expires.
func (r *GameRoom) handleAbandonmentTimeout(disconnectedPlayerID string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.IsGameOver {
		return
	}

	log.Info().
		Str("game_id", r.GameID).
		Str("disconnected_player", disconnectedPlayerID).
		Msg("Grace period expired - game forfeit by abandonment")

	// Determine winner
	var winnerID string
	var winnerColor string

	if disconnectedPlayerID == r.Game.RedPlayerID {
		winnerID = r.Game.BlackPlayerID
		winnerColor = "black"
	} else {
		winnerID = r.Game.RedPlayerID
		winnerColor = "red"
	}

	r.endGame(winnerID, winnerColor, models.ResultTypeAbandonment)
}

// HandleMove processes a move from a player.
func (r *GameRoom) HandleMove(client *Client, from, to string, pieceType string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.IsGameOver {
		sendErrorToClient(client, "game_ended", "Game has already ended")
		return
	}

	// Validate it's the player's turn
	var playerColor string
	if client.DeviceID == r.Game.RedPlayerID {
		playerColor = "red"
	} else {
		playerColor = "black"
	}

	if string(r.CurrentTurn) != playerColor {
		sendErrorToClient(client, "not_your_turn", "It's not your turn")
		return
	}

	// Record the move in the database
	move := &models.Move{
		GameID:       r.GameID,
		MoveNumber:   r.MoveCount + 1,
		PlayerID:     client.DeviceID,
		FromPosition: from,
		ToPosition:   to,
		PieceType:    models.PieceType(pieceType),
		Timestamp:    time.Now(),
	}

	if err := r.GameService.RecordMove(context.Background(), move); err != nil {
		log.Error().Err(err).Msg("Failed to record move")
		sendErrorToClient(client, "move_failed", "Failed to record move")
		return
	}

	r.MoveCount++

	// Switch turn
	if r.CurrentTurn == models.PlayerColorRed {
		r.CurrentTurn = models.PlayerColorBlack
	} else {
		r.CurrentTurn = models.PlayerColorRed
	}

	// Switch timer
	r.Timer.SwitchTurn()

	// Send confirmation to the player who moved
	r.sendMoveResult(client, true, move, nil)

	// Broadcast to opponent
	r.broadcastOpponentMove(client, move)
}

// HandleRollbackRequest processes a rollback request.
func (r *GameRoom) HandleRollbackRequest(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.IsGameOver {
		sendErrorToClient(client, "game_ended", "Game has already ended")
		return
	}

	// Check if there's already a pending rollback
	if r.PendingRollback != nil {
		sendErrorToClient(client, "rollback_pending", "A rollback request is already pending")
		return
	}

	// Check if player has rollbacks remaining
	var rollbacksRemaining int
	if client.DeviceID == r.Game.RedPlayerID {
		rollbacksRemaining = r.Game.RedRollbacksRemaining
	} else {
		rollbacksRemaining = r.Game.BlackRollbacksRemaining
	}

	if rollbacksRemaining <= 0 {
		sendErrorToClient(client, "no_rollbacks", "No rollbacks remaining")
		return
	}

	// Create pending rollback
	r.PendingRollback = &RollbackRequest{
		RequestingPlayerID: client.DeviceID,
		MoveNumberToRevert: r.MoveCount,
		RequestedAt:        time.Now(),
		TimeoutSeconds:     30,
	}

	// Start 30-second timeout
	r.RollbackTimeout = time.AfterFunc(30*time.Second, func() {
		r.handleRollbackTimeout()
	})

	// Send request to opponent
	r.broadcastRollbackRequest(client)

	log.Info().
		Str("game_id", r.GameID).
		Str("requester", client.DeviceID).
		Int("move_number", r.MoveCount).
		Msg("Rollback requested")
}

// HandleRollbackResponse processes a response to a rollback request.
func (r *GameRoom) HandleRollbackResponse(client *Client, accept bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.PendingRollback == nil {
		sendErrorToClient(client, "no_request", "No pending rollback request")
		return
	}

	// Cancel timeout timer
	if r.RollbackTimeout != nil {
		r.RollbackTimeout.Stop()
		r.RollbackTimeout = nil
	}

	requestingPlayerID := r.PendingRollback.RequestingPlayerID
	moveNumber := r.PendingRollback.MoveNumberToRevert
	r.PendingRollback = nil

	if accept {
		// Decrement rollback count for the requesting player
		if err := r.GameService.UseRollback(context.Background(), r.GameID, requestingPlayerID); err != nil {
			log.Error().Err(err).Msg("Failed to decrement rollback count")
		}

		// Update local game state
		if requestingPlayerID == r.Game.RedPlayerID {
			r.Game.RedRollbacksRemaining--
		} else {
			r.Game.BlackRollbacksRemaining--
		}

		// Revert game state
		if err := r.GameService.RevertToMove(context.Background(), r.GameID, moveNumber-1); err != nil {
			log.Error().Err(err).Msg("Failed to revert game state")
		}

		r.MoveCount = moveNumber - 1

		// Switch turn back
		if r.CurrentTurn == models.PlayerColorRed {
			r.CurrentTurn = models.PlayerColorBlack
		} else {
			r.CurrentTurn = models.PlayerColorRed
		}

		log.Info().
			Str("game_id", r.GameID).
			Bool("accepted", accept).
			Msg("Rollback executed")
	}

	// Get remaining rollbacks for the requester
	var rollbacksRemaining int
	if requestingPlayerID == r.Game.RedPlayerID {
		rollbacksRemaining = r.Game.RedRollbacksRemaining
	} else {
		rollbacksRemaining = r.Game.BlackRollbacksRemaining
	}

	// Broadcast result to both players
	r.broadcastRollbackResult(accept, rollbacksRemaining)
}

// handleRollbackTimeout is called when the rollback response times out.
func (r *GameRoom) handleRollbackTimeout() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.PendingRollback == nil {
		return
	}

	log.Info().
		Str("game_id", r.GameID).
		Str("requester", r.PendingRollback.RequestingPlayerID).
		Msg("Rollback request timed out")

	r.PendingRollback = nil
	r.RollbackTimeout = nil

	// Broadcast decline
	r.broadcastRollbackResult(false, 0)
}

// HandleResign processes a resignation.
func (r *GameRoom) HandleResign(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.IsGameOver {
		return
	}

	var winnerID, winnerColor string
	if client.DeviceID == r.Game.RedPlayerID {
		winnerID = r.Game.BlackPlayerID
		winnerColor = "black"
	} else {
		winnerID = r.Game.RedPlayerID
		winnerColor = "red"
	}

	r.endGame(winnerID, winnerColor, models.ResultTypeResignation)
}

// HandleDrawOffer processes a draw offer.
func (r *GameRoom) HandleDrawOffer(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.IsGameOver {
		return
	}

	// Broadcast draw offer to opponent
	message := OutgoingMessage{
		Type: "draw_offered",
		Payload: map[string]interface{}{
			"offerer":         client.DeviceID,
			"timeout_seconds": 30,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}

	r.broadcastExcept(client, message)
}

// HandleDrawResponse processes a draw response.
func (r *GameRoom) HandleDrawResponse(client *Client, accept bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.IsGameOver {
		return
	}

	if accept {
		r.endGame("", "", models.ResultTypeDraw)
	} else {
		// Notify that draw was declined
		message := OutgoingMessage{
			Type: "draw_declined",
			Payload: map[string]interface{}{
				"declined_by": client.DeviceID,
			},
			Timestamp: time.Now(),
			MessageID: generateMessageID(),
		}
		r.broadcast(message)
	}
}

// endGame ends the game with the specified result.
func (r *GameRoom) endGame(winnerID, winnerColor string, resultType models.ResultType) {
	r.IsGameOver = true

	// Stop the timer
	r.Timer.Stop()

	// Update game in database
	var winnerIDPtr *string
	if winnerID != "" {
		winnerIDPtr = &winnerID
	}

	if err := r.GameService.EndGame(context.Background(), r.GameID, winnerIDPtr, resultType); err != nil {
		log.Error().Err(err).Msg("Failed to end game")
	}

	// Broadcast game end
	message := OutgoingMessage{
		Type: "game_end",
		Payload: map[string]interface{}{
			"result_type":  string(resultType),
			"winner_id":    winnerID,
			"winner_color": winnerColor,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}

	r.broadcast(message)

	log.Info().
		Str("game_id", r.GameID).
		Str("winner_id", winnerID).
		Str("result_type", string(resultType)).
		Msg("Game ended")
}

// Helper methods for broadcasting

func (r *GameRoom) broadcast(msg OutgoingMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal message")
		return
	}
	r.Hub.BroadcastToGame(r.GameID, data)
}

func (r *GameRoom) broadcastExcept(sender *Client, msg OutgoingMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal message")
		return
	}
	r.Hub.Broadcast(&BroadcastMessage{
		GameID:  r.GameID,
		Message: data,
		Sender:  sender,
	})
}

func (r *GameRoom) broadcastConnectionStatus(status string, playerID string) {
	message := OutgoingMessage{
		Type: "connection_status",
		Payload: map[string]interface{}{
			"status":    status,
			"player_id": playerID,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}
	r.broadcast(message)
}

func (r *GameRoom) sendGameState() {
	redTime, blackTime, currentTurn, _ := r.Timer.GetState()

	message := OutgoingMessage{
		Type: "game_state",
		Payload: map[string]interface{}{
			"game_id":          r.GameID,
			"current_turn":     currentTurn,
			"move_count":       r.MoveCount,
			"red_time":         redTime,
			"black_time":       blackTime,
			"red_rollbacks":    r.Game.RedRollbacksRemaining,
			"black_rollbacks":  r.Game.BlackRollbacksRemaining,
			"is_check":         false, // TODO: Get from game state
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}
	r.broadcast(message)
}

func (r *GameRoom) sendMoveResult(client *Client, success bool, move *models.Move, error *string) {
	payload := map[string]interface{}{
		"success": success,
	}

	if success && move != nil {
		payload["move"] = map[string]interface{}{
			"from":        move.FromPosition,
			"to":          move.ToPosition,
			"piece_type":  string(move.PieceType),
			"move_number": move.MoveNumber,
			"is_check":    move.IsCheck,
		}
	}

	if error != nil {
		payload["error"] = *error
	}

	message := OutgoingMessage{
		Type:      "move_result",
		Payload:   payload,
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}

	data, _ := json.Marshal(message)
	client.Send <- data
}

func (r *GameRoom) broadcastOpponentMove(sender *Client, move *models.Move) {
	message := OutgoingMessage{
		Type: "opponent_move",
		Payload: map[string]interface{}{
			"from":        move.FromPosition,
			"to":          move.ToPosition,
			"piece_type":  string(move.PieceType),
			"move_number": move.MoveNumber,
			"is_check":    move.IsCheck,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}
	r.broadcastExcept(sender, message)
}

func (r *GameRoom) broadcastRollbackRequest(requester *Client) {
	message := OutgoingMessage{
		Type: "rollback_requested",
		Payload: map[string]interface{}{
			"requester":       requester.DeviceID,
			"move_to_revert":  r.MoveCount,
			"timeout_seconds": 30,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}
	r.broadcastExcept(requester, message)
}

func (r *GameRoom) broadcastRollbackResult(accepted bool, rollbacksRemaining int) {
	message := OutgoingMessage{
		Type: "rollback_result",
		Payload: map[string]interface{}{
			"accepted":            accepted,
			"rollbacks_remaining": rollbacksRemaining,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}
	r.broadcast(message)
}

func sendErrorToClient(client *Client, code, message string) {
	msg := OutgoingMessage{
		Type: "error",
		Payload: map[string]interface{}{
			"code":    code,
			"message": message,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}
	data, _ := json.Marshal(msg)
	client.Send <- data
}
