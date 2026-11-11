# Homelab Hub — execution metrics

Dani's first module for the Homelab Hub: PostgreSQL execution records, SQL metrics,
and a provisioned Grafana dashboard. The email workflow, Python summarization service,
Ollama and team VPN will be integrated by the other module owners.

This standalone module lives in `metrics/`. The original project documentation and
license remain at the repository root. See the
[Portuguese guide](docs/GUIA_DANI.md) for a guided introduction and the
[integration contract](docs/INTEGRATION.md) before connecting producers.

## Local development

Requirements: Docker Engine/Desktop with Docker Compose. Run commands from this
folder in Bash/WSL (`cd metrics` from the repository root). First create your local configuration:

```bash
cp .env.example .env
```

Edit `.env` and replace all four placeholder passwords with different random values.
Generate each with `python3 -c "import secrets; print(secrets.token_hex(24))"`.
The file is ignored by Git. Do not share it or commit it.

```bash
docker compose -f compose.metrics.yaml up -d --wait
```

Grafana: <http://localhost:53000>, username `dani`, password from
`GRAFANA_ADMIN_PASSWORD`. Open **Dashboards → Homelab Hub → Workflow executions**.
PostgreSQL is available at `127.0.0.1:55432`, database `homelab`.
Change the ports in `.env` if they conflict with another project.
Both published ports bind only to localhost. This setup is for local development;
remote access and transport security must be agreed with the infrastructure owner.

Grafana connects using `grafana_reader`, which can only read the metrics view.
Producers use `metrics_writer`, which can select, insert and update execution rows,
but cannot delete them. The owner account is reserved for initialization/maintenance.

## Optional synthetic demo

No sample data is loaded on startup. To create 48 finished attempts plus one slow
running attempt for the dashboard:

```bash
docker compose -f compose.metrics.yaml exec -T postgres psql -U homelab_owner -d homelab -v ON_ERROR_STOP=1 < db/seed/demo.sql
```

All synthetic rows use workflow `demo-email-digest`. Repeating the command does not
duplicate them. Their original timestamps remain unchanged, so increase the dashboard
time range if inspecting them on a later day. Use a separate database/Compose project
for the real deployment; do not treat these rows as production measurements.

## Validation and SQL

```bash
docker compose -f compose.metrics.yaml exec -T postgres psql -U homelab_owner -d homelab < tests/metrics.sql
docker compose -f compose.metrics.yaml exec -T postgres psql -U homelab_owner -d homelab -v ON_ERROR_STOP=1 < db/queries/overview.sql
docker compose -f compose.metrics.yaml exec -T postgres psql -U homelab_owner -d homelab -v ON_ERROR_STOP=1 < db/queries/hourly.sql
docker compose -f compose.metrics.yaml exec -T postgres psql -U homelab_owner -d homelab -v ON_ERROR_STOP=1 < db/queries/stale_runs.sql
```

The tests cover invalid counts/status/times, duplicate execution IDs, guarded completion,
duration units, empty batches, partial failures, success-rate semantics and role permissions.
They roll back all their data. Run them against a development database.

Validate the provisioned dashboard queries through Grafana's API (Python standard
library only). Enter your Grafana password at the prompt; for another port, set
`GRAFANA_URL` to its local address:

```bash
python3 tests/check_dashboard.py
```

This checks datasource connectivity and all nine panel queries, including Grafana SQL
macros. It does not replace a visual check in the browser.

## Stop, persistence and changes

```bash
docker compose -f compose.metrics.yaml down
```

This preserves the database and Grafana named volumes. Do not add `--volumes` unless
you explicitly intend to delete the stored data. Initialization runs on an empty database
volume only. Changing `.env` passwords later does not rotate database roles or an existing
Grafana administrator account; coordinate an explicit credential rotation.
Schema changes after deployment must be new migrations, not edits to the initial file.

PostgreSQL data uses the official image's PostgreSQL 18 volume layout. This module
does not change a pre-existing PostgreSQL installation or start the rest of the Homelab.
Backup/restoration, retention and the shared deployment remain integration tasks.

## Team workflow

Work on the `dani/metrics` branch and submit changes through a pull request for peer
review before merging into `main`. The root README, setup guide and license belong
to the shared project and are preserved by this module. Use the repository's root
MIT license.

## References

- [PostgreSQL constraints](https://www.postgresql.org/docs/18/ddl-constraints.html)
- [Grafana PostgreSQL configuration and read-only access](https://grafana.com/docs/grafana/latest/datasources/postgres/configure/)
- [Grafana provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Docker Compose service readiness](https://docs.docker.com/compose/how-tos/startup-order/)
