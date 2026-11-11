# Local validation — 2026-11-11

Environment: Docker Desktop, Docker Compose, `postgres:18` and
`grafana/grafana:13.2.1`. Commands are documented in the README.

Passed:

- Fresh-volume initialization, role creation and Compose startup.
- SQL tests, with all test rows rolled back: invalid counts, integer overflow in
  counter checks, lifecycle consistency, timestamps, duplicate attempt IDs,
  conditional completion, empty batches, partial failures, millisecond durations,
  success-rate calculation and writer/reader permissions.
- Grafana health and actual PostgreSQL datasource health.
- All nine provisioned panel queries through Grafana's API, first against an empty
  database, then with synthetic data. This includes SQL macro expansion.
- Demo loading twice: the second load inserted zero rows. The database contains
  49 synthetic attempts: 42 succeeded, 6 failed and 1 running.
- Standalone overview, hourly and stale-run queries against the demo dataset.

The 24-hour overview initially selected 48 attempts because the oldest sample starts
exactly 24 hours before loading and falls outside the moving window. It reported
41 successes, 6 failures, 1 running attempt, a success rate of 87.23%, a mean completed
duration of 5800 ms and a P95 of 9940 ms. These windowed results change with time.

Not yet validated: browser layout, real email/n8n/Python/Discord integration, a chosen
local model, the shared VPN, backup restoration and migration into the team's server.
No email account was accessed and no Discord messages were sent.

The development services were left running on localhost ports 55432 and 53000.
Original planning PDFs and the GitHub Desktop shortcut were preserved. Validation was performed before packaging the standalone module into the shared
repository; no parent Git repository changes were performed.

## Correctness fixes — 2026-11-11

- Added migration `002` without editing `001` or rewriting any existing execution rows.
- Applied `001` and `002` to a separate temporary database and ran the SQL tests there.
- Verified that completed successes and failures reject changed status, counters,
  identifiers, timestamps and model/error metadata, even without a producer status guard.
- Verified that identical no-op updates, progress updates and completion of running
  attempts still work. SQL test fixtures were rolled back.
- Ran the actual stale-panel SQL with a two-day-old running fixture and short,
  24-hour and historical time windows. The attempt remained counted in every case;
  test data was rolled back.
- Applied `002` to the existing local database and updated the services to use the
  repository's `metrics/` bind mounts, retaining the existing named volumes.
- Repeated the SQL and stale-panel regression tests against the upgraded database.
- Validated all nine live Grafana panel queries through its API, including an unchanged
  stale-attempt count for 5-minute, 24-hour and historical selected ranges.
- Confirmed that all 49 existing rows were preserved: the count and deterministic
  content fingerprint were identical before and after the upgrade and tests.
- Removed the separate temporary test database after successful validation.

Real email/workflow integration, browser layout, VPN and backup restoration remain
outside this validation, as listed above.

## n8n integration — 2026-11-11

Reviewed upstream: Lourenço's workflow/Compose at commit
`fa435272d550f8f0b53e878797e922d7cfdb68fe` (PR #5). Exact snapshots are preserved
under `integration/upstream/`; the instrumented export has its own ID and is inactive.

Passed:

- Seven pure JavaScript behavior tests covering preparation, empty inboxes, sanitized
  errors, complete/unique summaries, priorities, chunking and delivery aggregation.
- Real n8n `2.47.4` execution with Postgres 17 for n8n and Postgres 18 for metrics,
  on two isolated internal Docker networks with no published ports.
- Twelve synthetic scenarios: success, empty inbox, Gmail failure, invalid JSON,
  missing summaries, duplicate indices, invalid priority, provider unavailable,
  provider timeout, Discord failure, multipart success and partial multipart failure.
- Each scenario produced exactly one terminal metrics row with expected counts and
  code. Failed cases also failed the n8n execution after recording the metrics.
- A repeated successful fixture with a fixed execution identity stopped at the explicit
  acquisition gate, kept one row and made no extra model or delivery requests.
- Invalid/empty/failed summaries made no delivery calls. Multipart posts respected
  message size and disabled mention parsing; completion occurred once per attempt.
- The workflow used a real `metrics_writer` credential, generated only for the isolated
  tests. Gmail was replaced with synthetic items and all HTTP calls targeted local mocks.
- The network overlay merged with the reviewed upstream Compose file, with unambiguous
  `n8n-postgres` and `metrics-postgres` aliases and the correct read-only workflow mount.
- Updated the existing metrics service with its network alias; all nine Grafana queries
  still passed and the original 49 rows retained their exact content fingerprint.
- Temporary test projects and their volumes were removed by the test runner.

No real email credentials, Ollama instance or Discord webhook were used. The account-based
end-to-end test still needs coordination with Lourenço. Afonso's `/summarize` API contract
and the shared remote deployment remain separate integration tasks. Root project files
and Lourenço's branch/workflow were not overwritten.
