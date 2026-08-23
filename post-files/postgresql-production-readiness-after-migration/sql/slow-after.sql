\set ON_ERROR_STOP on
\pset pager off

CREATE INDEX IF NOT EXISTS idx_orders_customer_status
    ON orders (customer_id, status);
ANALYZE orders;

SELECT 'AFTER INDEX: indexed lookup evidence' AS phase;
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS)
SELECT count(*)
FROM orders
WHERE customer_id = 4241
  AND status = 'paid';

SELECT query, calls, total_exec_time::numeric(12,3), mean_exec_time::numeric(12,3), rows
FROM pg_stat_statements
WHERE query LIKE '%FROM orders%customer_id%'
ORDER BY total_exec_time DESC
LIMIT 5;
