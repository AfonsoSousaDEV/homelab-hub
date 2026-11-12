# Homelab Hub

@AGENTS.md

`AGENTS.md` holds the team rules, ownership, interfaces and the way AI assistants must work in this repository. This file only adds what is specific to the Docker stack. If the two disagree, `AGENTS.md` wins.

## Commands

- `./scripts/init-env.sh`: create `.env` with random secrets (never overwrites an existing one)
- `docker compose up -d` / `docker compose ps` / `docker compose logs -f <service>`
- `./scripts/pull-model.sh [model]`: download a model into Ollama (default `qwen3:4b`)
- `docker compose config --quiet`: validate the compose files without starting anything

## Stack constraints

- Everything must run on consumer hardware (6 GB VRAM at most): small models (3-4B), short context.
- Ports bind to `127.0.0.1` by default. Never publish Postgres or Ollama on `0.0.0.0`.
- Keep `.env.example` up to date when adding a variable; never commit `.env`.
- Pin image versions (`N8N_VERSION`, `OLLAMA_VERSION`) once something works.
- A native Ollama on the host and the `ollama` container both use port 11434: run only one at a time.

## Where to look

- `setup.md`: onboarding (WSL2, Docker, Git, SSH).
- `docs/architecture.md`: how the services fit together.
- Record every architecture decision as a short note in `docs/decisions/` (create the folder when the first one is needed).
