#!/usr/bin/env bash
set -euo pipefail
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS shop;
USE shop;
CREATE TABLE IF NOT EXISTS orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  customer_email VARCHAR(255) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS incidents (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  service_name VARCHAR(64) NOT NULL,
  symptom VARCHAR(255) NOT NULL,
  evidence VARCHAR(500) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO orders(customer_email, amount, status)
VALUES ('demo-a@example.test', 128.00, 'paid'),
       ('demo-b@example.test', 256.00, 'paid'),
       ('demo-c@example.test', 512.00, 'pending');
INSERT INTO incidents(service_name, symptom, evidence)
VALUES ('checkout-api', 'order search latency increased', 'unindexed wildcard filter observed during the demo');
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'exporter-demo-only';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
CREATE USER IF NOT EXISTS 'agent_reader'@'%' IDENTIFIED BY '${MYSQL_AGENT_PASSWORD}';
GRANT SELECT, SHOW VIEW ON shop.* TO 'agent_reader'@'%';
FLUSH PRIVILEGES;
SQL
