-- Diagnostic only: a slow run is not automatically declared failed.
SELECT workflow_key, execution_key, started_at,
       now() - started_at AS running_for
FROM metrics.run_metrics
WHERE status = 'running' AND started_at < now() - interval '15 minutes'
ORDER BY started_at;
