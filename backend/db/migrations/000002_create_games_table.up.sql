-- Migration: Create games table
-- Chinese Chess (Xiangqi) Backend

-- Create enum types for game status and result type
CREATE TYPE game_status AS ENUM ('active', 'completed', 'abandoned');
CREATE TYPE result_type AS ENUM ('checkmate', 'timeout', 'resignation', 'abandonment', 'draw', 'stalemate');

CREATE TABLE IF NOT EXISTS games (
    -- UUID as primary key
    id VARCHAR(36) PRIMARY KEY,

    -- Player references
    red_player_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    black_player_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Game status
    status game_status NOT NULL DEFAULT 'active',
    winner_id VARCHAR(255) REFERENCES users(id) ON DELETE SET NULL,
    result_type result_type,

    -- Game settings
    turn_timeout_seconds INTEGER NOT NULL DEFAULT 300,

    -- Rollback tracking
    red_rollbacks_remaining INTEGER NOT NULL DEFAULT 3,
    black_rollbacks_remaining INTEGER NOT NULL DEFAULT 3,

    -- Game statistics
    total_moves INTEGER NOT NULL DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Constraints
    CONSTRAINT different_players CHECK (red_player_id != black_player_id),
    CONSTRAINT valid_rollbacks_red CHECK (red_rollbacks_remaining >= 0 AND red_rollbacks_remaining <= 3),
    CONSTRAINT valid_rollbacks_black CHECK (black_rollbacks_remaining >= 0 AND black_rollbacks_remaining <= 3),
    CONSTRAINT valid_timeout CHECK (turn_timeout_seconds >= 0)
);

-- Index for finding games by player
CREATE INDEX IF NOT EXISTS idx_games_red_player ON games(red_player_id);
CREATE INDEX IF NOT EXISTS idx_games_black_player ON games(black_player_id);

-- Index for finding active games
CREATE INDEX IF NOT EXISTS idx_games_status ON games(status);

-- Index for sorting by creation date (newest first)
CREATE INDEX IF NOT EXISTS idx_games_created_at ON games(created_at DESC);

-- Composite index for player game history queries
CREATE INDEX IF NOT EXISTS idx_games_player_history ON games(red_player_id, created_at DESC)
    WHERE status = 'completed';
CREATE INDEX IF NOT EXISTS idx_games_player_history_black ON games(black_player_id, created_at DESC)
    WHERE status = 'completed';

COMMENT ON TABLE games IS 'Stores game records between two players';
COMMENT ON COLUMN games.id IS 'Unique game identifier (UUID)';
COMMENT ON COLUMN games.red_player_id IS 'Device ID of the red (first) player';
COMMENT ON COLUMN games.black_player_id IS 'Device ID of the black (second) player';
COMMENT ON COLUMN games.status IS 'Current game status: active, completed, or abandoned';
COMMENT ON COLUMN games.winner_id IS 'Device ID of the winner (NULL for draw)';
COMMENT ON COLUMN games.result_type IS 'How the game ended';
COMMENT ON COLUMN games.turn_timeout_seconds IS 'Time limit per turn (0 = unlimited)';
COMMENT ON COLUMN games.red_rollbacks_remaining IS 'Rollbacks left for red player (max 3)';
COMMENT ON COLUMN games.black_rollbacks_remaining IS 'Rollbacks left for black player (max 3)';
COMMENT ON COLUMN games.total_moves IS 'Total number of moves made in the game';
