#!/bin/sh
# Sourced by the official Postgres entrypoint on an empty volume only.
set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    --file /migrations/001_execution_metrics.sql

# Read passwords inside psql, avoiding SQL interpolation and process arguments.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
\getenv writer_password METRICS_WRITER_PASSWORD
\getenv reader_password GRAFANA_READER_PASSWORD
SELECT format('CREATE ROLE metrics_writer LOGIN PASSWORD %L', :'writer_password') \gexec
SELECT format('CREATE ROLE grafana_reader LOGIN PASSWORD %L', :'reader_password') \gexec

REVOKE ALL ON DATABASE homelab FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE homelab TO metrics_writer, grafana_reader;
GRANT USAGE ON SCHEMA metrics TO metrics_writer, grafana_reader;
GRANT SELECT, INSERT, UPDATE ON metrics.workflow_runs TO metrics_writer;
GRANT SELECT ON metrics.run_metrics TO grafana_reader;
ALTER ROLE grafana_reader SET statement_timeout = '10s';
ALTER ROLE grafana_reader SET default_transaction_read_only = on;
SQL
