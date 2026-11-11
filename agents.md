
# Homelab Backend — Codex Instructions

## Project
We are a team of 5 building a shared Homelab.

Our first project is an email summarization automation.

Architecture:
Email → n8n → Python FastAPI → Ollama → n8n → Telegram/Email

## My responsibility
I am responsible for the Python backend.

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
2. Create GET /health.
3. Create POST /summarize.
4. Integrate Ollama.
5. Write automated tests.
6. Dockerize the backend.

## Important instructions
- Act as my programming mentor.
- Explain concepts before implementing.
- Give me small tasks to solve myself.
- Do not implement everything at once.
- Review my code and explain mistakes.
- Prefer simple, maintainable solutions.
- Follow the project documents in docs/.
- Never commit credentials or real emails.
- Ask before making major architecture changes.

## Goal
Help me learn backend development while
building a real, working project.
