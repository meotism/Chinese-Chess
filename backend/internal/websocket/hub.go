// Package websocket handles WebSocket connections for real-time gameplay.
package websocket

import (
	"context"
	"sync"

	"github.com/rs/zerolog/log"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/services"
)

// Hub maintains the set of active clients and broadcasts messages to clients.
type Hub struct {
	// Registered clients per game
	rooms map[string]map[*Client]bool

	// Inbound messages from clients
	broadcast chan *BroadcastMessage

	// Register requests from clients
	register chan *Client

	// Unregister requests from clients
	unregister chan *Client

	// Game service for handling game logic
	gameService *services.GameService

	// Room manager for game rooms with timers and state
	roomManager *RoomManager

	// Mutex for thread-safe operations
	mu sync.RWMutex

	// Shutdown channel
	shutdown chan struct{}
}

// BroadcastMessage represents a message to broadcast to a game room.
type BroadcastMessage struct {
	GameID  string
	Message []byte
	Sender  *Client
}

// NewHub creates a new Hub.
func NewHub(gameService *services.GameService) *Hub {
	return &Hub{
		rooms:       make(map[string]map[*Client]bool),
		broadcast:   make(chan *BroadcastMessage, 256),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		gameService: gameService,
		roomManager: NewRoomManager(),
		shutdown:    make(chan struct{}),
	}
}

// GetRoomManager returns the room manager.
func (h *Hub) GetRoomManager() *RoomManager {
	return h.roomManager
}

// GetGameService returns the game service.
func (h *Hub) GetGameService() *services.GameService {
	return h.gameService
}

// GetOrCreateRoom gets an existing room or creates a new one for a game.
func (h *Hub) GetOrCreateRoom(gameID string) (*GameRoom, error) {
	// Try to get existing room
	room := h.roomManager.GetRoom(gameID)
	if room != nil {
		return room, nil
	}

	// Fetch game from database
	game, err := h.gameService.GetGame(context.Background(), gameID)
	if err != nil {
		return nil, err
	}

	// Create new room
	room = h.roomManager.CreateRoom(gameID, game, h, h.gameService)
	return room, nil
}

// RemoveRoom removes a game room.
func (h *Hub) RemoveRoom(gameID string) {
	h.roomManager.RemoveRoom(gameID)
}

// GetRoom gets a game room by ID.
func (h *Hub) GetRoom(gameID string) *GameRoom {
	return h.roomManager.GetRoom(gameID)
}

// HandleGameEnd is called when a game ends (by any means).
func (h *Hub) HandleGameEnd(gameID string, winnerID string, resultType models.ResultType) {
	ctx := context.Background()

	var winnerIDPtr *string
	if winnerID != "" {
		winnerIDPtr = &winnerID
	}

	if err := h.gameService.EndGame(ctx, gameID, winnerIDPtr, resultType); err != nil {
		log.Error().Err(err).Str("game_id", gameID).Msg("Failed to end game")
	}

	// Clean up room after a delay to allow final messages to be sent
	// The room cleanup happens in the room itself
}

// Run starts the hub's main loop.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.registerClient(client)

		case client := <-h.unregister:
			h.unregisterClient(client)

		case message := <-h.broadcast:
			h.broadcastToRoom(message)

		case <-h.shutdown:
			h.closeAllConnections()
			return
		}
	}
}

// Shutdown gracefully shuts down the hub.
func (h *Hub) Shutdown() {
	close(h.shutdown)
}

// Register adds a client to the hub.
func (h *Hub) Register(client *Client) {
	h.register <- client
}

// Unregister removes a client from the hub.
func (h *Hub) Unregister(client *Client) {
	h.unregister <- client
}

// Broadcast sends a message to all clients in a game room.
func (h *Hub) Broadcast(message *BroadcastMessage) {
	h.broadcast <- message
}

// BroadcastToGame sends a message to all clients in a specific game.
func (h *Hub) BroadcastToGame(gameID string, message []byte) {
	h.Broadcast(&BroadcastMessage{
		GameID:  gameID,
		Message: message,
		Sender:  nil,
	})
}

// GetClientsInGame returns all clients in a game room.
func (h *Hub) GetClientsInGame(gameID string) []*Client {
	h.mu.RLock()
	defer h.mu.RUnlock()

	room, exists := h.rooms[gameID]
	if !exists {
		return nil
	}

	clients := make([]*Client, 0, len(room))
	for client := range room {
		clients = append(clients, client)
	}
	return clients
}

// GetOpponent returns the opponent client for a given client in a game.
func (h *Hub) GetOpponent(gameID string, deviceID string) *Client {
	h.mu.RLock()
	defer h.mu.RUnlock()

	room, exists := h.rooms[gameID]
	if !exists {
		return nil
	}

	for client := range room {
		if client.DeviceID != deviceID {
			return client
		}
	}
	return nil
}

// registerClient adds a client to its game room.
func (h *Hub) registerClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.rooms[client.GameID] == nil {
		h.rooms[client.GameID] = make(map[*Client]bool)
	}
	h.rooms[client.GameID][client] = true

	log.Info().
		Str("game_id", client.GameID).
		Str("device_id", client.DeviceID).
		Msg("Client registered to game room")

	// Notify other players in the room
	h.notifyRoomOfConnection(client, true)
}

// unregisterClient removes a client from its game room.
func (h *Hub) unregisterClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if room, exists := h.rooms[client.GameID]; exists {
		if _, ok := room[client]; ok {
			delete(room, client)
			close(client.Send)

			log.Info().
				Str("game_id", client.GameID).
				Str("device_id", client.DeviceID).
				Msg("Client unregistered from game room")

			// Notify the game room for disconnection handling
			if gameRoom := h.roomManager.GetRoom(client.GameID); gameRoom != nil {
				gameRoom.LeavePlayer(client)
			}

			// Notify other players in the room
			h.notifyRoomOfConnection(client, false)

			// Clean up empty rooms
			if len(room) == 0 {
				delete(h.rooms, client.GameID)
			}
		}
	}
}

// broadcastToRoom sends a message to all clients in a game room.
func (h *Hub) broadcastToRoom(message *BroadcastMessage) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	room, exists := h.rooms[message.GameID]
	if !exists {
		return
	}

	for client := range room {
		// Don't send to the sender (unless sender is nil, meaning it's a server message)
		if message.Sender != nil && client == message.Sender {
			continue
		}

		select {
		case client.Send <- message.Message:
		default:
			// Client's buffer is full, close connection
			close(client.Send)
			delete(room, client)
		}
	}
}

// notifyRoomOfConnection notifies other players when someone connects/disconnects.
func (h *Hub) notifyRoomOfConnection(client *Client, connected bool) {
	room := h.rooms[client.GameID]
	if room == nil {
		return
	}

	var messageType string
	if connected {
		messageType = "opponent_connected"
	} else {
		messageType = "opponent_disconnected"
	}

	message := []byte(`{"type":"connection_status","payload":{"` + messageType + `":true}}`)

	for other := range room {
		if other != client {
			select {
			case other.Send <- message:
			default:
			}
		}
	}
}

// closeAllConnections closes all client connections.
func (h *Hub) closeAllConnections() {
	h.mu.Lock()
	defer h.mu.Unlock()

	for gameID, room := range h.rooms {
		for client := range room {
			close(client.Send)
			delete(room, client)
		}
		delete(h.rooms, gameID)
	}
}
