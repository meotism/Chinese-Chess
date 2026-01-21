// Package websocket handles WebSocket connections for real-time gameplay.
package websocket

import (
	"encoding/json"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"
)

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer.
	maxMessageSize = 512
)

// Client represents a WebSocket client connection.
type Client struct {
	Hub      *Hub
	Conn     *websocket.Conn
	Send     chan []byte
	GameID   string
	DeviceID string
}

// NewClient creates a new client.
func NewClient(hub *Hub, conn *websocket.Conn, gameID, deviceID string) *Client {
	return &Client{
		Hub:      hub,
		Conn:     conn,
		Send:     make(chan []byte, 256),
		GameID:   gameID,
		DeviceID: deviceID,
	}
}

// ReadPump pumps messages from the WebSocket connection to the hub.
func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister(c)
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Error().Err(err).Msg("WebSocket read error")
			}
			break
		}

		// Handle incoming message
		c.handleMessage(message)
	}
}

// WritePump pumps messages from the hub to the WebSocket connection.
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued messages to the current websocket message
			n := len(c.Send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.Send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleMessage processes an incoming message from the client.
func (c *Client) handleMessage(data []byte) {
	var msg IncomingMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		log.Error().Err(err).Str("data", string(data)).Msg("Failed to parse message")
		c.sendError("invalid_message", "Invalid message format")
		return
	}

	log.Debug().
		Str("type", msg.Type).
		Str("game_id", c.GameID).
		Str("device_id", c.DeviceID).
		Msg("Received message")

	switch msg.Type {
	case "join":
		c.handleJoin(msg.Payload)
	case "move":
		c.handleMove(msg.Payload)
	case "rollback_request":
		c.handleRollbackRequest(msg.Payload)
	case "rollback_response":
		c.handleRollbackResponse(msg.Payload)
	case "draw_offer":
		c.handleDrawOffer(msg.Payload)
	case "draw_response":
		c.handleDrawResponse(msg.Payload)
	case "resign":
		c.handleResign(msg.Payload)
	case "ping":
		c.handlePing()
	default:
		c.sendError("unknown_type", "Unknown message type: "+msg.Type)
	}
}

// Message handlers

func (c *Client) handleJoin(payload json.RawMessage) {
	// Get or create game room
	room, err := c.Hub.GetOrCreateRoom(c.GameID)
	if err != nil {
		c.sendError("game_not_found", "Game not found")
		return
	}

	// Join the room
	if err := room.JoinPlayer(c); err != nil {
		c.sendError("join_failed", err.Error())
		return
	}

	// Game state is sent by the room when both players are connected
	log.Info().
		Str("game_id", c.GameID).
		Str("device_id", c.DeviceID).
		Msg("Player joined game")
}

func (c *Client) handleMove(payload json.RawMessage) {
	var move MovePayload
	if err := json.Unmarshal(payload, &move); err != nil {
		c.sendError("invalid_move", "Invalid move format")
		return
	}

	// Get the game room
	room := c.Hub.GetRoom(c.GameID)
	if room == nil {
		c.sendError("room_not_found", "Game room not found")
		return
	}

	// Delegate move handling to the room
	room.HandleMove(c, move.From, move.To, move.PieceType)
}

func (c *Client) handleRollbackRequest(payload json.RawMessage) {
	// Get the game room
	room := c.Hub.GetRoom(c.GameID)
	if room == nil {
		c.sendError("room_not_found", "Game room not found")
		return
	}

	// Delegate to room
	room.HandleRollbackRequest(c)
}

func (c *Client) handleRollbackResponse(payload json.RawMessage) {
	var response struct {
		Accept bool `json:"accept"`
	}
	if err := json.Unmarshal(payload, &response); err != nil {
		c.sendError("invalid_response", "Invalid rollback response format")
		return
	}

	// Get the game room
	room := c.Hub.GetRoom(c.GameID)
	if room == nil {
		c.sendError("room_not_found", "Game room not found")
		return
	}

	// Delegate to room
	room.HandleRollbackResponse(c, response.Accept)
}

func (c *Client) handleDrawOffer(payload json.RawMessage) {
	// Get the game room
	room := c.Hub.GetRoom(c.GameID)
	if room == nil {
		c.sendError("room_not_found", "Game room not found")
		return
	}

	// Delegate to room
	room.HandleDrawOffer(c)
}

func (c *Client) handleDrawResponse(payload json.RawMessage) {
	var response struct {
		Accept bool `json:"accept"`
	}
	if err := json.Unmarshal(payload, &response); err != nil {
		c.sendError("invalid_response", "Invalid draw response format")
		return
	}

	// Get the game room
	room := c.Hub.GetRoom(c.GameID)
	if room == nil {
		c.sendError("room_not_found", "Game room not found")
		return
	}

	// Delegate to room
	room.HandleDrawResponse(c, response.Accept)
}

func (c *Client) handleResign(payload json.RawMessage) {
	// Get the game room
	room := c.Hub.GetRoom(c.GameID)
	if room == nil {
		c.sendError("room_not_found", "Game room not found")
		return
	}

	// Delegate to room
	room.HandleResign(c)
}

func (c *Client) handlePing() {
	c.send(OutgoingMessage{
		Type: "pong",
		Payload: map[string]interface{}{
			"server_time": time.Now().Format(time.RFC3339),
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	})
}

// Helper methods

func (c *Client) send(msg OutgoingMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal message")
		return
	}
	c.Send <- data
}

func (c *Client) sendError(code, message string) {
	c.send(OutgoingMessage{
		Type: "error",
		Payload: map[string]interface{}{
			"code":    code,
			"message": message,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	})
}

// Message types

// IncomingMessage represents a message from a client.
type IncomingMessage struct {
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	Timestamp time.Time       `json:"timestamp"`
	MessageID string          `json:"message_id"`
}

// OutgoingMessage represents a message to a client.
type OutgoingMessage struct {
	Type      string                 `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp time.Time              `json:"timestamp"`
	MessageID string                 `json:"message_id"`
}

// MovePayload represents a move message payload.
type MovePayload struct {
	From      string `json:"from"`
	To        string `json:"to"`
	PieceType string `json:"piece_type"`
}

// generateMessageID generates a unique message ID.
func generateMessageID() string {
	return time.Now().Format("20060102150405.000000")
}
