\set ON_ERROR_STOP on
\pset pager off

SELECT 'BEFORE INDEX: sequential scan evidence' AS phase;
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS)
SELECT count(*)
FROM orders
WHERE customer_id = 4241
  AND status = 'paid';
