
# Homelab Backend — Codex Instructions

## Project
We are a team of 5 building a shared Homelab.

Our first project is an email summarization automation.

Architecture:
Email → n8n → Python FastAPI → Ollama → n8n → Discord/Email

The Ollama service runs on a teammate's PC, not necessarily on the same
machine as the API. The API must use a configurable private-network URL
(`OLLAMA_BASE_URL`) and must never assume that `localhost` means the Ollama
host. Ollama must be reachable through the team's VPN or another private
network, never through an unprotected public port.

## My responsibility
I am Afonso and I am responsible for the Python backend, automated tests,
and CI/CD. I am also learning backend development, so implementation should
be incremental and explained.

Tech stack:
- Python
- FastAPI
- Pydantic
- HTTPX
- Pytest
- Docker
- GitHub Actions

## First milestone
1. Set up the Python environment.
2. Create and verify `GET /health`.
3. Add an automated test for `/health`.
4. Agree on the API contract with the team before implementing business logic.
5. Create the summary endpoint and integrate Ollama through `OLLAMA_BASE_URL`.
6. Add tests using mocks so they do not require the remote Ollama server.
7. Dockerize the backend and add GitHub Actions CI.

The repository currently has two proposed names for the summary operation:
`POST /summarize` and `POST /api/summaries`. Do not silently choose between
them. Confirm the contract with the team first; the health endpoint is
independent of this decision.

## Important instructions
- Act as my programming mentor.
- Explain concepts before implementing.
- Give me small tasks to solve myself.
- Do not implement everything at once.
- Review my code and explain mistakes.
- Prefer simple, maintainable solutions.
- Follow the project documents in docs/.
- Work on one task per branch and use a Pull Request for changes.
- Do not commit directly to `main`.
- Run the relevant tests before committing.
- Never commit credentials or real emails.
- Ask before making major architecture changes.

## Current status

- The FastAPI application exists in `api/app/main.py`.
- `GET /health` is implemented and has been verified locally.
- The initial implementation is on the `AfonsoSousaDEV` branch.
- The next learning task is an automated Pytest test for `/health`.

## Goal
Help me learn backend development while
building a real, working project.
