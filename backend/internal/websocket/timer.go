// Package websocket handles WebSocket connections for real-time gameplay.
package websocket

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/rs/zerolog/log"
)

// GameTimer manages the turn timer for a specific game.
type GameTimer struct {
	GameID           string
	Hub              *Hub
	RedTimeRemaining int
	BlackTimeRemaining int
	CurrentTurn      string // "red" or "black"
	TurnTimeout      int    // timeout in seconds per turn
	IsPaused         bool   // paused during disconnection
	IsRunning        bool

	mu       sync.RWMutex
	ticker   *time.Ticker
	stopChan chan struct{}
	done     chan struct{}
}

// TimerManager manages all active game timers.
type TimerManager struct {
	timers map[string]*GameTimer
	mu     sync.RWMutex
}

// NewTimerManager creates a new TimerManager.
func NewTimerManager() *TimerManager {
	return &TimerManager{
		timers: make(map[string]*GameTimer),
	}
}

// CreateTimer creates a new timer for a game.
func (m *TimerManager) CreateTimer(gameID string, hub *Hub, turnTimeout int) *GameTimer {
	m.mu.Lock()
	defer m.mu.Unlock()

	// If a timer already exists, stop it first
	if existing, ok := m.timers[gameID]; ok {
		existing.Stop()
	}

	timer := &GameTimer{
		GameID:             gameID,
		Hub:                hub,
		RedTimeRemaining:   turnTimeout,
		BlackTimeRemaining: turnTimeout,
		CurrentTurn:        "red", // Red always starts
		TurnTimeout:        turnTimeout,
		IsPaused:           false,
		IsRunning:          false,
		stopChan:           make(chan struct{}),
		done:               make(chan struct{}),
	}

	m.timers[gameID] = timer
	return timer
}

// GetTimer retrieves a timer for a game.
func (m *TimerManager) GetTimer(gameID string) *GameTimer {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.timers[gameID]
}

// RemoveTimer removes a timer for a game.
func (m *TimerManager) RemoveTimer(gameID string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if timer, ok := m.timers[gameID]; ok {
		timer.Stop()
		delete(m.timers, gameID)
	}
}

// Start begins the timer countdown.
func (t *GameTimer) Start() {
	t.mu.Lock()
	if t.IsRunning {
		t.mu.Unlock()
		return
	}
	t.IsRunning = true
	t.ticker = time.NewTicker(1 * time.Second)
	t.stopChan = make(chan struct{})
	t.done = make(chan struct{})
	t.mu.Unlock()

	go t.run()

	log.Info().
		Str("game_id", t.GameID).
		Int("turn_timeout", t.TurnTimeout).
		Msg("Timer started")
}

// Stop halts the timer.
func (t *GameTimer) Stop() {
	t.mu.Lock()
	defer t.mu.Unlock()

	if !t.IsRunning {
		return
	}

	t.IsRunning = false
	close(t.stopChan)

	if t.ticker != nil {
		t.ticker.Stop()
	}

	// Wait for the run goroutine to finish
	select {
	case <-t.done:
	case <-time.After(2 * time.Second):
		log.Warn().Str("game_id", t.GameID).Msg("Timer stop timeout")
	}

	log.Info().Str("game_id", t.GameID).Msg("Timer stopped")
}

// Pause pauses the timer (e.g., during player disconnection).
func (t *GameTimer) Pause() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.IsPaused = true
	log.Info().Str("game_id", t.GameID).Msg("Timer paused")
}

// Resume resumes the timer after a pause.
func (t *GameTimer) Resume() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.IsPaused = false
	log.Info().Str("game_id", t.GameID).Msg("Timer resumed")
}

// SwitchTurn switches the active turn and resets the current player's time.
func (t *GameTimer) SwitchTurn() {
	t.mu.Lock()
	defer t.mu.Unlock()

	if t.CurrentTurn == "red" {
		t.CurrentTurn = "black"
		t.BlackTimeRemaining = t.TurnTimeout
	} else {
		t.CurrentTurn = "red"
		t.RedTimeRemaining = t.TurnTimeout
	}

	log.Debug().
		Str("game_id", t.GameID).
		Str("current_turn", t.CurrentTurn).
		Msg("Turn switched")
}

// UpdateFromServer updates the timer with server-authoritative values.
func (t *GameTimer) UpdateFromServer(redTime, blackTime int, currentTurn string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.RedTimeRemaining = redTime
	t.BlackTimeRemaining = blackTime
	t.CurrentTurn = currentTurn
}

// GetState returns the current timer state.
func (t *GameTimer) GetState() (redTime, blackTime int, currentTurn string, isPaused bool) {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.RedTimeRemaining, t.BlackTimeRemaining, t.CurrentTurn, t.IsPaused
}

// run is the main timer loop.
func (t *GameTimer) run() {
	defer close(t.done)

	for {
		select {
		case <-t.stopChan:
			return

		case <-t.ticker.C:
			t.tick()
		}
	}
}

// tick decrements the current player's time by one second.
func (t *GameTimer) tick() {
	t.mu.Lock()

	if t.IsPaused {
		t.mu.Unlock()
		return
	}

	var timeoutOccurred bool
	var loserColor string

	if t.CurrentTurn == "red" {
		t.RedTimeRemaining--
		if t.RedTimeRemaining <= 0 {
			t.RedTimeRemaining = 0
			timeoutOccurred = true
			loserColor = "red"
		}
	} else {
		t.BlackTimeRemaining--
		if t.BlackTimeRemaining <= 0 {
			t.BlackTimeRemaining = 0
			timeoutOccurred = true
			loserColor = "black"
		}
	}

	redTime := t.RedTimeRemaining
	blackTime := t.BlackTimeRemaining
	currentTurn := t.CurrentTurn
	t.mu.Unlock()

	// Broadcast timer update to clients every second
	t.broadcastTimerUpdate(redTime, blackTime, currentTurn)

	// Handle timeout
	if timeoutOccurred {
		t.handleTimeout(loserColor)
	}
}

// broadcastTimerUpdate sends timer state to all clients in the game.
func (t *GameTimer) broadcastTimerUpdate(redTime, blackTime int, currentTurn string) {
	message := OutgoingMessage{
		Type: "timer",
		Payload: map[string]interface{}{
			"red_time":     redTime,
			"black_time":   blackTime,
			"current_turn": currentTurn,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}

	data, err := json.Marshal(message)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal timer update")
		return
	}

	t.Hub.BroadcastToGame(t.GameID, data)
}

// handleTimeout handles a timeout event (player loses).
func (t *GameTimer) handleTimeout(loserColor string) {
	log.Info().
		Str("game_id", t.GameID).
		Str("loser_color", loserColor).
		Msg("Timer timeout - game forfeit")

	// Determine winner
	var winnerColor string
	if loserColor == "red" {
		winnerColor = "black"
	} else {
		winnerColor = "red"
	}

	// Broadcast game end message
	message := OutgoingMessage{
		Type: "game_end",
		Payload: map[string]interface{}{
			"result_type":   "timeout",
			"winner_color":  winnerColor,
			"timeout_color": loserColor,
		},
		Timestamp: time.Now(),
		MessageID: generateMessageID(),
	}

	data, err := json.Marshal(message)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal game end message")
		return
	}

	t.Hub.BroadcastToGame(t.GameID, data)

	// Stop the timer
	go t.Stop()

	// Notify the hub to handle game end
	t.Hub.HandleGameTimeout(t.GameID, winnerColor)
}

// HandleGameTimeout notifies when a game ends due to timeout.
func (h *Hub) HandleGameTimeout(gameID string, winnerColor string) {
	// This will be implemented to update the game record in the database
	// and perform any necessary cleanup
	log.Info().
		Str("game_id", gameID).
		Str("winner_color", winnerColor).
		Msg("Game ended due to timeout")

	// End the game in the game service
	if h.gameService != nil {
		// Get winner player ID based on color
		// This requires game state information which we'll handle in the game room
	}
}
