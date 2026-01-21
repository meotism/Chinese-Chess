-- Initial database setup script
-- This script runs when the PostgreSQL container is first created

-- Create the xiangqi database if it doesn't exist
-- (This is handled by POSTGRES_DB environment variable, but kept for documentation)

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE xiangqi TO postgres;

-- Log initialization
DO $$
BEGIN
    RAISE NOTICE 'Database initialized successfully';
END $$;
