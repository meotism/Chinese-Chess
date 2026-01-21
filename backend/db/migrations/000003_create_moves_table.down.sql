-- Rollback: Drop moves table

DROP INDEX IF EXISTS idx_moves_game_move_number;
DROP INDEX IF EXISTS idx_moves_player;
DROP INDEX IF EXISTS idx_moves_game_id;
DROP TABLE IF EXISTS moves;
DROP TYPE IF EXISTS piece_type;
