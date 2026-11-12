# Architecture

Three containers on one private Docker network (`hub`), defined in `compose.yaml`.

```
 your browser / scripts
        |  (127.0.0.1 only, see BIND_ADDRESS)
        |-- :5678  --> n8n ----------+--> postgres (n8n database + "hub" database)
        |                            |
        '-- :11434 --> ollama <------'   n8n calls http://ollama:11434 over the private network
```

| Service | Image | Published port | Persistent volume | Purpose |
| --- | --- | --- | --- | --- |
| `postgres` | `postgres:17-alpine` | none (internal only) | `postgres_data` | Stores n8n's workflows and our own tables |
| `n8n` | `docker.n8n.io/n8nio/n8n` | 5678 | `n8n_data` | Workflow automation |
| `ollama` | `ollama/ollama` | 11434 | `ollama_data` | Local LLM server |

## Decisions

- **Postgres, not SQLite, for n8n.** One database server for n8n and for our own data, and it is closer to what a real deployment looks like.
- **Two databases.** `n8n` is created by the image; `hub` is created by `postgres/init/01-create-hub-db.sql` and is for our own tables (execution log, metrics).
- **Ollama in a container.** Same version for everyone and nothing installed globally. GPU support is an opt-in override (`compose.gpu.yaml`) so the stack still starts on machines without an NVIDIA card.
- **Localhost by default.** Postgres is never published; n8n and Ollama listen on `BIND_ADDRESS` (`127.0.0.1`). Ollama has no authentication, so it must not be exposed beyond a private network such as a VPN.
- **Small context.** `OLLAMA_CONTEXT_LENGTH=4096` and one loaded model at a time keep 3-4B models fully on a 6 GB GPU.

## Planned, not built yet

- Python service (FastAPI) with `GET /health` and `POST /summarize` in front of Ollama, with automated tests. Owner: Afonso; see `AGENTS.md` for the agreed flow.
- n8n workflow that summarizes a test mailbox each day through that service. Delivery channel (Telegram or email) is still to be confirmed; see `AGENTS.md`.
- Execution log tables in the `hub` database and a Grafana dashboard on top.
- Private access for the group (VPN): the approach is still open.
