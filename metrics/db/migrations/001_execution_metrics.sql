-- Run once against the metrics database as its owner. No email bodies or secrets.
BEGIN;

CREATE SCHEMA metrics;

CREATE TABLE metrics.workflow_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_key text NOT NULL CHECK (workflow_key ~ '^[a-z][a-z0-9_-]{0,79}$'),
    -- Stable orchestration execution ID, never a subject, address or message body.
    execution_key text NOT NULL CHECK (length(execution_key) BETWEEN 1 AND 120),
    status text NOT NULL DEFAULT 'running'
        CHECK (status IN ('running', 'succeeded', 'failed')),
    started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    finished_at timestamptz,
    emails_total integer NOT NULL DEFAULT 0 CHECK (emails_total >= 0),
    emails_summarized integer NOT NULL DEFAULT 0 CHECK (emails_summarized >= 0),
    emails_failed integer NOT NULL DEFAULT 0 CHECK (emails_failed >= 0),
    model_name text CHECK (length(model_name) BETWEEN 1 AND 120),
    error_code text CHECK (error_code ~ '^[A-Z][A-Z0-9_]{1,63}$'),
    CONSTRAINT run_identity UNIQUE (workflow_key, execution_key),
    CONSTRAINT email_counts CHECK (
        emails_summarized::bigint + emails_failed::bigint <= emails_total::bigint
    ),
    CONSTRAINT chronological_run CHECK (finished_at IS NULL OR finished_at >= started_at),
    CONSTRAINT lifecycle CHECK (
        (status = 'running' AND finished_at IS NULL AND error_code IS NULL)
        OR (status = 'succeeded' AND finished_at IS NOT NULL AND error_code IS NULL
            AND emails_summarized = emails_total AND emails_failed = 0)
        OR (status = 'failed' AND finished_at IS NOT NULL AND error_code IS NOT NULL)
    )
);

CREATE INDEX workflow_runs_started_at_idx ON metrics.workflow_runs (started_at DESC);
CREATE INDEX workflow_runs_workflow_started_idx
    ON metrics.workflow_runs (workflow_key, started_at DESC);
CREATE INDEX workflow_runs_unfinished_idx
    ON metrics.workflow_runs (started_at) WHERE status = 'running';

CREATE VIEW metrics.run_metrics AS
SELECT id, workflow_key, execution_key, status, started_at, finished_at,
       emails_total, emails_summarized, emails_failed, model_name, error_code,
       -- End-to-end workflow duration, not just the LLM request latency.
       extract(epoch FROM (finished_at - started_at)) * 1000 AS duration_ms
FROM metrics.workflow_runs;

COMMENT ON TABLE metrics.workflow_runs IS
    'One row per workflow attempt. Metadata only; no email content or raw exceptions.';
COMMENT ON COLUMN metrics.workflow_runs.error_code IS
    'Sanitized category, e.g. OLLAMA_TIMEOUT, IMAP_UNAVAILABLE, DISCORD_SEND_FAILED.';
COMMENT ON COLUMN metrics.workflow_runs.emails_total IS
    'Emails selected for this attempt. A successful empty batch has all counters zero.';

COMMIT;
