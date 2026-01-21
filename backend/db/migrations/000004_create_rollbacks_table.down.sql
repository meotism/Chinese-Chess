-- Rollback: Drop rollbacks table

DROP INDEX IF EXISTS idx_rollbacks_pending;
DROP INDEX IF EXISTS idx_rollbacks_game_id;
DROP TABLE IF EXISTS rollbacks;
DROP TYPE IF EXISTS rollback_status;
