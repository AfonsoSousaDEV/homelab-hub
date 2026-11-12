-- Last 24 hours, by workflow. Running attempts are excluded from success/latency.
SELECT workflow_key,
       count(*) AS executions,
       count(*) FILTER (WHERE status = 'running') AS running,
       count(*) FILTER (WHERE status = 'succeeded') AS succeeded,
       count(*) FILTER (WHERE status = 'failed') AS failed,
       round(100.0 * count(*) FILTER (WHERE status = 'succeeded')
             / nullif(count(*) FILTER (WHERE status <> 'running'), 0), 2) AS success_pct,
       sum(emails_summarized) AS emails_summarized,
       round(avg(duration_ms), 2) AS mean_duration_ms,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95_duration_ms
FROM metrics.run_metrics
WHERE started_at >= now() - interval '24 hours'
GROUP BY workflow_key
ORDER BY workflow_key;
