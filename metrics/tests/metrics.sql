\set ON_ERROR_STOP on
-- Run as database owner in a development database; all test rows roll back.
BEGIN;

CREATE FUNCTION pg_temp.expect_check(statement text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN check_violation THEN
        RETURN;
    END;
    RAISE EXCEPTION 'Expected CHECK violation: %', statement;
END;
$$;

SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, emails_total) VALUES ('test', 'negative', -1)$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, emails_total, emails_summarized, emails_failed)
    VALUES ('test', 'counts', 1, 1, 1)$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, emails_total, emails_summarized, emails_failed)
    VALUES ('test', 'overflow', 2147483647, 2147483647, 1)$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status) VALUES ('test', 'unknown', 'unknown')$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status) VALUES ('test', 'unfinished', 'succeeded')$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, finished_at) VALUES ('test', 'running-ended', now())$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status, finished_at)
    VALUES ('test', 'missing-error', 'failed', now() + interval '1 second')$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status, started_at, finished_at)
    VALUES ('test', 'backwards', 'succeeded', now(), now() - interval '1 second')$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status, finished_at, emails_total)
    VALUES ('test', 'incomplete-success', 'succeeded', now() + interval '1 second', 2)$q$);
SELECT pg_temp.expect_check($q$INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status, finished_at, error_code)
    VALUES ('test', 'unsafe-error', 'failed', now() + interval '1 second', 'Email: someone@example.org')$q$);

-- Exercise the same privileges as n8n/Python, including retry behaviour.
SET LOCAL ROLE metrics_writer;
INSERT INTO metrics.workflow_runs (workflow_key, execution_key, started_at)
VALUES ('test', 'lifecycle', now() - interval '10 seconds');
INSERT INTO metrics.workflow_runs (workflow_key, execution_key)
VALUES ('test', 'lifecycle') ON CONFLICT (workflow_key, execution_key) DO NOTHING;
UPDATE metrics.workflow_runs
SET status = 'succeeded', finished_at = started_at + interval '2.5 seconds',
    emails_total = 2, emails_summarized = 2
WHERE workflow_key = 'test' AND execution_key = 'lifecycle' AND status = 'running';

DO $$
DECLARE changed integer;
BEGIN
    UPDATE metrics.workflow_runs SET status = 'failed', error_code = 'LATE_RETRY'
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle' AND status = 'running';
    GET DIAGNOSTICS changed = ROW_COUNT;
    IF changed <> 0 THEN RAISE EXCEPTION 'Retry rewrote a completed run'; END IF;
    IF (SELECT count(*) FROM metrics.workflow_runs
        WHERE workflow_key = 'test' AND execution_key = 'lifecycle') <> 1 THEN
        RAISE EXCEPTION 'Duplicate execution was recorded';
    END IF;
    BEGIN
        DELETE FROM metrics.workflow_runs WHERE workflow_key = 'test';
        RAISE EXCEPTION 'Writer unexpectedly has DELETE permission';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

-- These updates would satisfy all original CHECK constraints. The database guard,
-- rather than a producer's WHERE status = 'running', must reject each change.
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET status = 'failed', error_code = 'TEST_REWRITE'
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle'$q$);
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET status = 'running', finished_at = NULL
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle'$q$);
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET emails_total = 3, emails_summarized = 3
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle'$q$);
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET model_name = 'rewritten-model'
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle'$q$);
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET finished_at = finished_at + interval '1 second'
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle'$q$);
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET execution_key = 'rewritten-identity'
    WHERE workflow_key = 'test' AND execution_key = 'lifecycle'$q$);

-- An unchanged retry is harmless and may still return the existing row.
UPDATE metrics.workflow_runs SET model_name = model_name
WHERE workflow_key = 'test' AND execution_key = 'lifecycle';
RESET ROLE;

INSERT INTO metrics.workflow_runs (workflow_key, execution_key, status, started_at, finished_at)
VALUES ('test', 'empty-success', 'succeeded', now() - interval '2 seconds', now());
INSERT INTO metrics.workflow_runs
    (workflow_key, execution_key, status, started_at, finished_at, emails_total,
     emails_summarized, emails_failed, error_code)
VALUES ('test', 'partial-failure', 'failed', now() - interval '3 seconds', now(),
        5, 2, 1, 'OLLAMA_TIMEOUT');
INSERT INTO metrics.workflow_runs (workflow_key, execution_key)
VALUES ('test', 'still-running');

SET LOCAL ROLE metrics_writer;
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET status = 'succeeded', error_code = NULL, emails_summarized = 5, emails_failed = 0
    WHERE workflow_key = 'test' AND execution_key = 'partial-failure'$q$);
SELECT pg_temp.expect_check($q$UPDATE metrics.workflow_runs
    SET error_code = 'OTHER_FAILURE'
    WHERE workflow_key = 'test' AND execution_key = 'partial-failure'$q$);

-- Progress updates and failed completion remain valid while a run is running.
INSERT INTO metrics.workflow_runs (workflow_key, execution_key, emails_total)
VALUES ('test-active', 'progress', 2);
UPDATE metrics.workflow_runs SET emails_summarized = 1
WHERE workflow_key = 'test-active' AND execution_key = 'progress';
UPDATE metrics.workflow_runs
SET status = 'failed', finished_at = clock_timestamp(), error_code = 'OLLAMA_TIMEOUT'
WHERE workflow_key = 'test-active' AND execution_key = 'progress';
RESET ROLE;

SET LOCAL ROLE grafana_reader;
DO $$
DECLARE rate numeric;
BEGIN
    IF (SELECT duration_ms FROM metrics.run_metrics
        WHERE workflow_key = 'test' AND execution_key = 'lifecycle') <> 2500 THEN
        RAISE EXCEPTION 'Duration is not measured in milliseconds';
    END IF;
    IF (SELECT duration_ms FROM metrics.run_metrics
        WHERE workflow_key = 'test' AND execution_key = 'still-running') IS NOT NULL THEN
        RAISE EXCEPTION 'Running attempt has a completed duration';
    END IF;
    SELECT round(100.0 * count(*) FILTER (WHERE status = 'succeeded')
         / nullif(count(*) FILTER (WHERE status <> 'running'), 0), 2) INTO rate
    FROM metrics.run_metrics WHERE workflow_key = 'test';
    IF rate <> 66.67 THEN RAISE EXCEPTION 'Wrong success rate: %', rate; END IF;
END;
$$;
RESET ROLE;

-- Check ACLs independently of default_transaction_read_only.
DO $$
BEGIN
    IF NOT has_table_privilege('grafana_reader', 'metrics.run_metrics', 'SELECT')
       OR has_table_privilege('grafana_reader', 'metrics.workflow_runs', 'INSERT')
       OR has_table_privilege('grafana_reader', 'metrics.workflow_runs', 'UPDATE')
       OR has_table_privilege('grafana_reader', 'metrics.workflow_runs', 'DELETE')
       OR has_schema_privilege('grafana_reader', 'metrics', 'CREATE')
       OR has_database_privilege('grafana_reader', current_database(), 'CREATE') THEN
        RAISE EXCEPTION 'Grafana permissions are incorrect';
    END IF;
END;
$$;

ROLLBACK;
\echo 'PASS: constraints, immutable completed runs, progress, retries, durations, success rate and permissions'
