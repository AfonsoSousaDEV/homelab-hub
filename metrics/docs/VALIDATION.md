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
