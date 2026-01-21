-- Migration: Create rollbacks table
-- Chinese Chess (Xiangqi) Backend

-- Create enum type for rollback status
CREATE TYPE rollback_status AS ENUM ('pending', 'accepted', 'declined', 'expired');

CREATE TABLE IF NOT EXISTS rollbacks (
    -- Auto-incrementing ID
    id BIGSERIAL PRIMARY KEY,

    -- Game reference
    game_id VARCHAR(36) NOT NULL REFERENCES games(id) ON DELETE CASCADE,

    -- Rollback information
    requesting_player_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    move_number_reverted INTEGER NOT NULL,

    -- Status
    status rollback_status NOT NULL DEFAULT 'pending',

    -- Timestamp
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_move_reverted CHECK (move_number_reverted > 0)
);

-- Index for fetching rollbacks by game
CREATE INDEX IF NOT EXISTS idx_rollbacks_game_id ON rollbacks(game_id);

-- Index for finding pending rollbacks
CREATE INDEX IF NOT EXISTS idx_rollbacks_pending ON rollbacks(game_id, status)
    WHERE status = 'pending';

COMMENT ON TABLE rollbacks IS 'Tracks rollback requests in games';
COMMENT ON COLUMN rollbacks.id IS 'Auto-incrementing rollback request ID';
COMMENT ON COLUMN rollbacks.game_id IS 'Reference to the game';
COMMENT ON COLUMN rollbacks.requesting_player_id IS 'Device ID of player requesting rollback';
COMMENT ON COLUMN rollbacks.move_number_reverted IS 'The move number that was reverted to';
COMMENT ON COLUMN rollbacks.status IS 'Current status of the rollback request';
