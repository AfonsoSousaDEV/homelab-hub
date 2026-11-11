# n8n email digest → execution metrics

Owner: Dani; integration to review with Lourenço, Afonso and Martim.

This adds an **inactive, separately named workflow** to the email digest from
[Lourenço's PR #5](https://github.com/AfonsoSousaDEV/homelab-hub/pull/5), reviewed at
commit `fa435272d550f8f0b53e878797e922d7cfdb68fe`. The exact original workflow and
Compose file are preserved in `upstream/` for attribution and reproducibility. They
are reference snapshots, not the shared deployment or files to edit in his branch.

## Recorded lifecycle

1. Create one `running` row before reading Gmail, using the actual n8n execution ID.
2. An empty inbox finishes as `succeeded` with zero counters and no model/delivery call.
3. Record the selected email count, ask Ollama, and strictly validate its JSON.
4. Require exactly one valid summary per email index, with a known priority and nonempty
   summary. Missing/duplicate results fail as `INVALID_MODEL_RESPONSE` before delivery.
5. Record the summarized count, split the Discord message, and attempt delivery.
6. Collect all delivery outcomes into **one** terminal update. A partial delivery
   failure stays `failed` even when some chunks were accepted.
7. After recording failure, raise a sanitized n8n error. Manual and scheduled runs use
   the same inline path, independently of the automatic-only Error Trigger.

The writer uses parameterized SQL and the `metrics_writer` account. PostgreSQL metrics
receive only IDs, counts, times, model name and sanitized codes. Raw model output and
exceptions are not sent to Discord or stored in the metrics table. Discord mention
parsing is disabled on generated posts.

| Code | Meaning |
| --- | --- |
| `GMAIL_READ_FAILED` | Email retrieval failed. |
| `OLLAMA_UNAVAILABLE` | Model service/network/HTTP failure. |
| `OLLAMA_TIMEOUT` | Model request timeout. |
| `INVALID_MODEL_RESPONSE` | Invalid JSON, incomplete, duplicate or malformed summaries. |
| `DISCORD_SEND_FAILED` | At least one chunk failed or delivery results were incomplete. |

An unavailable metrics database prevents normal startup/completion of the attempt;
it cannot record its own outage. Crashes and unexpected errors can leave a `running`
row for the stale indicator to flag. A repeated start with the same workflow/execution
pair returns `acquired = false` and an explicit gate stops before processing. A new retry gets a new execution ID.
This does not deduplicate Gmail messages across executions or ensure exactly-once delivery.

The provider call follows Lourenço's current direct Ollama implementation. Replacing it
with Afonso's `/summarize` endpoint awaits that service's published request/response/error
contract. Do not add a second workflow metrics row in Python.

## Build and synthetic tests

From the repository root (Node.js, Python and Docker Compose; no npm install):

```bash
node metrics/integration/build-workflow.js
node --test metrics/integration/tests/logic.test.js
python3 metrics/integration/tests/run_integration.py
```

The runner starts real n8n `2.47.4`, Postgres 17 for n8n and Postgres 18 for metrics in a unique Docker Compose project,
with fresh test volumes and an **internal network without published ports**. Gmail is
replaced with synthetic items; Ollama and Discord HTTP calls target a local mock.
Normal n8n Postgres/HTTP/IF/Code nodes execute against this setup. No real credentials
or webhook URLs are imported. Generated test credential files are temporary. Cleanup
removes only that test project's containers and volumes.

The scenarios cover success, empty inbox, Gmail failure, malformed/missing/duplicate
summaries, invalid priority, unavailable model, timeout, delivery failure, multipart success
and partial multipart failure. Assertions check one row per attempt, counts, sanitized
codes, n8n success/failure and which services were called.
The successful fixture is executed twice with a fixed identity to prove a duplicate
start makes no extra model or delivery calls and preserves the original metrics row.

Edit `digest-logic.js` or `build-workflow.js`, then regenerate and review the JSON diff.
Do not independently edit copies of Code-node logic in the generated export.

## Connect the local Compose environments

Prerequisites: Lourenço's root Compose/setup must be available in the integration
checkout, and the team must agree to test the pinned n8n version. This branch keeps
those root files untouched. Postgres 17 stores n8n's internal data; Postgres 18 stores
metrics. No data-volume migration or password reuse between them is needed.

From the repository root, start/update metrics using its own local configuration:

```bash
docker compose --env-file metrics/.env -f metrics/compose.metrics.yaml up -d --wait
```

Keep the root `.env` from Lourenço's setup for n8n and `metrics/.env` for metrics.
Then attach n8n to both networks and import the separate inactive workflow:

```bash
docker compose -f docker-compose.yml -f metrics/integration/compose.n8n-metrics.yaml up -d
docker compose -f docker-compose.yml -f metrics/integration/compose.n8n-metrics.yaml exec -T n8n n8n import:workflow --input=/metrics-workflows/EmailDigestMetrics00001.json
```

Always use both `-f` arguments for later n8n Compose commands. The overlay bind path
is resolved from the root Compose file. The metrics network must exist first.

In n8n select **Email digest → Discord (metrics)**. Create/select a Postgres credential
in all four Postgres nodes:

| Setting | Value |
| --- | --- |
| Host | `metrics-postgres` |
| Port | `5432` |
| Database | `homelab` |
| User | `metrics_writer` |
| Password | `METRICS_WRITER_PASSWORD` from `metrics/.env` |
| SSL | Disabled for this local Docker network |

The overlay gives n8n's internal database the explicit alias `n8n-postgres` and overrides
`DB_POSTGRESDB_HOST` accordingly. Both original networks have a `postgres` service alias,
so relying on that ambiguous name from a container attached to both is unsafe.
Use `metrics-postgres` in the metrics credential. Martim must configure the agreed
network/security for a remote server.

Bind Gmail credentials to **Get unread emails**, and configure the root model/webhook
variables following Lourenço's guide. Keep the original digest inactive when testing
this variant to avoid two schedules. Importing does not publish the new workflow.
Use a dedicated email account and Discord test channel, verify the metrics row and
dashboard, then agree with the team before enabling the schedule.

Real account setup/delivery are outside the automated tests. n8n's own execution
history may contain payloads; agree its retention separately from metadata-only metrics.
