-- Rollback: Drop games table

DROP INDEX IF EXISTS idx_games_player_history_black;
DROP INDEX IF EXISTS idx_games_player_history;
DROP INDEX IF EXISTS idx_games_created_at;
DROP INDEX IF EXISTS idx_games_status;
DROP INDEX IF EXISTS idx_games_black_player;
DROP INDEX IF EXISTS idx_games_red_player;
DROP TABLE IF EXISTS games;
DROP TYPE IF EXISTS result_type;
DROP TYPE IF EXISTS game_status;
