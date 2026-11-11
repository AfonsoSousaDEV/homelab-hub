-- Runs once, when the Postgres volume is first created.
-- n8n uses the default database; "hub" is for our own tables (execution log, metrics, ...).
CREATE DATABASE hub;
