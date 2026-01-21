-- Migration: Create moves table
-- Chinese Chess (Xiangqi) Backend

-- Create enum type for piece types
CREATE TYPE piece_type AS ENUM ('general', 'advisor', 'elephant', 'horse', 'chariot', 'cannon', 'soldier');

CREATE TABLE IF NOT EXISTS moves (
    -- Auto-incrementing ID
    id BIGSERIAL PRIMARY KEY,

    -- Game reference
    game_id VARCHAR(36) NOT NULL REFERENCES games(id) ON DELETE CASCADE,

    -- Move information
    move_number INTEGER NOT NULL,
    player_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Position notation (e.g., "e0", "d4")
    from_position VARCHAR(3) NOT NULL,
    to_position VARCHAR(3) NOT NULL,

    -- Piece information
    piece_type piece_type NOT NULL,
    captured_piece piece_type,

    -- Check indicator
    is_check BOOLEAN NOT NULL DEFAULT FALSE,

    -- Timestamp
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_move_number CHECK (move_number > 0),
    CONSTRAINT different_positions CHECK (from_position != to_position)
);

-- Index for fetching moves by game (most common query)
CREATE INDEX IF NOT EXISTS idx_moves_game_id ON moves(game_id, move_number ASC);

-- Index for fetching a player's move history
CREATE INDEX IF NOT EXISTS idx_moves_player ON moves(player_id);

-- Unique constraint to prevent duplicate move numbers in a game
CREATE UNIQUE INDEX IF NOT EXISTS idx_moves_game_move_number ON moves(game_id, move_number);

COMMENT ON TABLE moves IS 'Stores individual moves in games for history and replay';
COMMENT ON COLUMN moves.id IS 'Auto-incrementing move ID';
COMMENT ON COLUMN moves.game_id IS 'Reference to the game this move belongs to';
COMMENT ON COLUMN moves.move_number IS 'Sequential move number in the game (1-indexed)';
COMMENT ON COLUMN moves.player_id IS 'Device ID of the player who made the move';
COMMENT ON COLUMN moves.from_position IS 'Starting position in algebraic notation (e.g., e0)';
COMMENT ON COLUMN moves.to_position IS 'Ending position in algebraic notation (e.g., e1)';
COMMENT ON COLUMN moves.piece_type IS 'Type of piece that was moved';
COMMENT ON COLUMN moves.captured_piece IS 'Type of piece captured (NULL if no capture)';
COMMENT ON COLUMN moves.is_check IS 'Whether this move resulted in check';
