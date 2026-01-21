-- Migration: Create users table
-- Chinese Chess (Xiangqi) Backend

CREATE TABLE IF NOT EXISTS users (
    -- Device ID as primary key (from IDFV)
    id VARCHAR(255) PRIMARY KEY,

    -- User display name (3-20 characters)
    display_name VARCHAR(50) NOT NULL,

    -- Game statistics
    total_games INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Index for faster lookups by display name (for opponent search)
CREATE INDEX IF NOT EXISTS idx_users_display_name ON users(display_name);

-- Index for leaderboard queries (by wins)
CREATE INDEX IF NOT EXISTS idx_users_wins ON users(wins DESC);

-- Trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE users IS 'Stores player profiles identified by device ID';
COMMENT ON COLUMN users.id IS 'Device identifier (IDFV from iOS)';
COMMENT ON COLUMN users.display_name IS 'User-chosen display name (3-20 chars)';
COMMENT ON COLUMN users.total_games IS 'Total number of completed games';
COMMENT ON COLUMN users.wins IS 'Number of games won';
COMMENT ON COLUMN users.losses IS 'Number of games lost';
COMMENT ON COLUMN users.draws IS 'Number of games drawn';
