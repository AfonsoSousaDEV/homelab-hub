-- Runs once, on first Postgres boot, via /docker-entrypoint-initdb.d.
-- n8n keeps its own tables in POSTGRES_DB (n8n); the application uses this one.
CREATE DATABASE homelab;
