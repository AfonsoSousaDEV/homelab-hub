# Metrics integration contract

Owner: Dani. Consumers: Afonso's Python service and Lourenço's n8n workflow.
This contract is a proposal for the first integration; review it together before merging.

## Connection and ownership

Database: `homelab`; writer role: `metrics_writer`; table: `metrics.workflow_runs`.
Inside the standalone Compose network use host `postgres`, port `5432`.
From the host use `127.0.0.1:55432` (or `POSTGRES_PORT`). In the shared deployment,
Martim must supply the network address and provision the roles in the agreed database.
Never use the owner account in n8n, Python or Grafana. Keep passwords in credentials
storage/environment configuration, never in workflow exports or Git.

**n8n owns one row per complete workflow attempt.** Python returns the summary or
an error category; it must not record a second workflow run for the same attempt.
The measured duration covers email retrieval, summarization and Discord delivery.
LLM request latency is not measured separately in version 1.

## Lifecycle

1. Before reading emails, insert a `running` row using the n8n execution ID.
2. Select that row by the same `(workflow_key, execution_key)` and retain its UUID.
   A repeated insert does not grant permission to send the same Discord message again.
3. After successful delivery, finish it as `succeeded` with final counters. An empty
   inbox is a successful attempt with all counters zero and no Discord delivery needed.
4. If any stage fails, finish it as `failed`, retaining partial counts and a sanitized
   category such as `IMAP_UNAVAILABLE`, `OLLAMA_TIMEOUT` or `DISCORD_SEND_FAILED`.
5. Update only rows whose current status is `running`. Zero updated rows means the
   attempt already finished or the ID is wrong; investigate instead of overwriting it.

If n8n crashes before finalizing, the row stays `running`; the dashboard flags attempts
older than 15 minutes. This is diagnostic, not proof of failure. Reconcile these rows
against n8n before correcting them. Retrying the actual workflow is a new attempt with
a new execution ID. Database row uniqueness does **not** provide exactly-once email
processing or Discord delivery; the workflow needs its own message deduplication strategy.

## Parameterized SQL

The examples below use PostgreSQL `$1` parameters. In the n8n Postgres node use
query parameters; with Python/psycopg adapt them to `%s` placeholders. Never build
SQL using string concatenation or interpolate email/model output into query text.

Start (parameters: workflow key, n8n execution ID, model identifier or null):

```sql
INSERT INTO metrics.workflow_runs (workflow_key, execution_key, model_name)
VALUES ($1, $2, $3)
ON CONFLICT (workflow_key, execution_key) DO NOTHING;
```

Read in a **separate statement** after the insert (parameters: workflow key, execution ID):

```sql
SELECT id, status FROM metrics.workflow_runs
WHERE workflow_key = $1 AND execution_key = $2;
```

Finish (parameters: UUID, status, selected email count, summarized count, failed count,
error code or null):

```sql
UPDATE metrics.workflow_runs
SET status = $2, finished_at = clock_timestamp(),
    emails_total = $3, emails_summarized = $4, emails_failed = $5, error_code = $6
WHERE id = $1::uuid AND status = 'running'
RETURNING id, status;
```

`succeeded` requires all selected emails to be summarized and no failed emails or error
code. A failed attempt can have zero failed emails: for example, all summaries succeeded
but delivery to Discord failed. Unprocessed emails may remain after an early failure, so
`emails_summarized + emails_failed` can be less than `emails_total`.

All timestamps are timezone-aware; send ISO 8601 timestamps with an explicit offset
if overriding the database defaults. Use the database clock for normal operation.
The dashboard filters attempts by **start time**. Success rate excludes running rows;
latency includes finished attempts of either outcome. No finished attempts means no
success-rate/latency value, rather than a misleading zero.

## Data minimization

Store counts, model identifiers, times and error categories only. Do not store subjects,
addresses, bodies, summaries, credentials or raw exceptions. The schema limits the shape
of fields but cannot detect every accidental disclosure: validate identifiers in producers.
Retention duration is an open team decision; no automatic deletion is configured.

## Joining the main Homelab

The standalone database belongs to this metrics module. Do not run its bootstrap script
against n8n's internal database: that script changes database-wide permissions.
Prefer a separate `homelab` metrics database and dedicated roles on the shared Postgres
server. Run the migration once as its owner, then adapt the grants and Grafana datasource.
Coordinate with Martim before changing the main Compose file or database naming.
