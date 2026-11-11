"""Run the actual stale-panel SQL against an old fixture, with all data rolled back.

Uses Docker Compose and the Python standard library. Run from the metrics folder.
Set METRICS_TEST_DB to target a separate development database if needed.
"""

import json
import os
from pathlib import Path
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    dashboard = json.loads((root / "grafana/dashboards/workflow-executions.json").read_text())
    panel = next(p for p in dashboard["panels"] if p["title"] == "Running for over 15 minutes")
    query = panel["targets"][0]["rawSql"]
    # Model Grafana's time macro for a short window, 24h and an entirely past window.
    # The original query fails: the two-day-old running fixture disappears.
    windows = [
        "started_at BETWEEN now() - interval '5 minutes' AND now()",
        "started_at BETWEEN now() - interval '24 hours' AND now()",
        "started_at BETWEEN now() - interval '30 days' AND now() - interval '29 days'",
    ]
    sql = """BEGIN;
CREATE TEMP TABLE expected_stale_count AS
SELECT count(*) + 1 AS total FROM metrics.run_metrics
WHERE status = 'running' AND started_at < now() - interval '15 minutes';
INSERT INTO metrics.workflow_runs (workflow_key, execution_key, started_at)
VALUES ('test-stale-panel', gen_random_uuid()::text, now() - interval '2 days');
"""
    for index, window in enumerate(windows, 1):
        expanded = query.replace("$__timeFilter(started_at)", window)
        sql += f"""
DO $assert$
DECLARE actual bigint; expected bigint;
BEGIN
    SELECT total INTO expected FROM expected_stale_count;
    EXECUTE $panel_query${expanded}$panel_query$ INTO actual;
    IF actual IS DISTINCT FROM expected THEN
        RAISE EXCEPTION 'Window {index}: expected % stale runs, got %', expected, actual;
    END IF;
END;
$assert$;
"""
    sql += "ROLLBACK;\n"
    result = subprocess.run([
        "docker", "compose", "-f", "compose.metrics.yaml", "exec", "-T", "postgres",
        "psql", "-X", "-U", "homelab_owner", "-d", os.environ.get("METRICS_TEST_DB", "homelab"),
        "-v", "ON_ERROR_STOP=1",
    ], input=sql, text=True, cwd=root, capture_output=True)
    if result.returncode:
        raise SystemExit(result.stderr or result.stdout)
    print("PASS: old running attempt remains counted for 5-minute, 24-hour and historical windows")
    print("PASS: panel test data rolled back")


if __name__ == "__main__":
    main()
