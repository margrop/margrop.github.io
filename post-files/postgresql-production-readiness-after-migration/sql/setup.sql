\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id integer NOT NULL,
    status text NOT NULL,
    amount numeric(12,2) NOT NULL,
    payload text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO orders (customer_id, status, amount, payload)
SELECT
    1 + (g % 10000),
    CASE WHEN g % 4 = 0 THEN 'paid' ELSE 'pending' END,
    ((g % 50000) / 100.0)::numeric(12,2),
    repeat(md5(g::text), 3)
FROM generate_series(1, 300000) AS g;

ANALYZE orders;

DROP TABLE IF EXISTS recovery_probe;
CREATE TABLE recovery_probe (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    note text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO recovery_probe (note) VALUES ('base_backup_exists');
