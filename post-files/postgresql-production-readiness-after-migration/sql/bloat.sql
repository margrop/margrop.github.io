\set ON_ERROR_STOP on
\pset pager off

ALTER TABLE orders SET (autovacuum_enabled = false);
UPDATE orders
SET payload = payload || '-changed'
WHERE id % 2 = 0;
DELETE FROM orders WHERE id % 10 = 0;
ANALYZE orders;

SELECT pg_stat_force_next_flush();
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    vacuum_count,
    autovacuum_count,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
WHERE relname = 'orders';
