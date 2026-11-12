-- Optional SYNTHETIC data. Run only in a development/demo database.
-- Stable keys make repeated loads harmless; timestamps use the first load time.
BEGIN;
INSERT INTO metrics.workflow_runs (
    workflow_key, execution_key, status, started_at, finished_at,
    emails_total, emails_summarized, emails_failed, model_name, error_code
)
SELECT 'demo-email-digest', 'demo-' || n,
       CASE WHEN n % 7 = 0 THEN 'failed' ELSE 'succeeded' END,
       now() - n * interval '30 minutes',
       now() - n * interval '30 minutes' + (1000 + n * 200) * interval '1 millisecond',
       5, CASE WHEN n % 7 = 0 THEN 2 ELSE 5 END,
       CASE WHEN n % 7 = 0 THEN 1 ELSE 0 END,
       'synthetic-model', CASE WHEN n % 7 = 0 THEN 'OLLAMA_TIMEOUT' END
FROM generate_series(1, 48) AS series(n)
ON CONFLICT (workflow_key, execution_key) DO NOTHING;

INSERT INTO metrics.workflow_runs (workflow_key, execution_key, started_at)
VALUES ('demo-email-digest', 'demo-running', now() - interval '20 minutes')
ON CONFLICT (workflow_key, execution_key) DO NOTHING;
COMMIT;
