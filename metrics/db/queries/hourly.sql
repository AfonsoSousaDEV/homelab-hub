-- UTC buckets. Missing hours are absent, not treated as failed executions.
SET TIME ZONE 'UTC';
SELECT date_trunc('hour', started_at) AS hour,
       count(*) AS executions,
       count(*) FILTER (WHERE status = 'failed') AS failed,
       sum(emails_summarized) AS emails_summarized,
       round(avg(duration_ms), 2) AS mean_duration_ms
FROM metrics.run_metrics
WHERE started_at >= now() - interval '7 days'
GROUP BY 1
ORDER BY 1;
