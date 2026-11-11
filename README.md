# homelab-hub
A lightweight homelab dashboard and automation utility for our team project.

## 🚀 Quick start

New to the project? First follow [setup.md](setup.md) (WSL2, Docker, Git, SSH). Then, from the repository root inside Ubuntu:

```bash
./scripts/init-env.sh          # creates .env with random secrets
docker compose up -d           # starts Postgres, n8n and Ollama
./scripts/pull-model.sh        # downloads qwen3:4b into Ollama
```

* n8n: http://localhost:5678
* Ollama API: http://localhost:11434
* NVIDIA GPU: set `COMPOSE_FILE=compose.yaml:compose.gpu.yaml` in `.env`, then check `docker compose exec ollama ollama ps`.

Ports are bound to `127.0.0.1` by default; see `BIND_ADDRESS` in `.env.example` before exposing anything.

| Path | What it is |
| --- | --- |
| `compose.yaml` | Postgres 17, n8n and Ollama on a private network |
| `compose.gpu.yaml` | NVIDIA GPU override for Ollama |
| `.env.example` | Settings template; the real `.env` is git-ignored |
| `postgres/init/` | SQL that runs once when the database volume is created |
| `scripts/` | Helpers to create `.env` and pull a model |
| `docs/architecture.md` | How the pieces fit together |
| `CLAUDE.md` | Stack-specific notes for Claude Code (imports `AGENTS.md`) |

## 🧠 Architectural & Tech Stack Overview

To achieve our goals of building a robust portfolio, exploring local AI (LLMs), and adopting professional software engineering practices, our team relies on a standardized, open-source technology stack. Here is why we use each component:

### 🐧 Ubuntu & WSL2 (The Standardized Development Environment)
* **What it is:** A real Linux environment running natively inside Windows with high performance.
* **Why we use it:** Modern software engineering—especially containerization, backend services, and AI tooling—is built natively for Linux. Using WSL2 ensures everyone on the team shares the exact same operating system layer, eliminating path issues (`/` vs `\`) and environment discrepancies ("it worked on my machine").

### 🔐 Sudo (System Administration & Security)
* **What it is:** *Superuser Do*, the mechanism to execute commands with elevated administrator permissions.
* **Why we use it:** Required for system-level configurations, installing packages securely, and setting up core development engines (like Docker) safely without risking accidental system changes.

### 🔑 SSH (Secure Cryptographic Authentication)
* **What it is:** A secure protocol using public/private key pairs for network communication.
* **Why we use it:** It secures our interaction with GitHub. By using SSH keys, we authenticate all code pushes and pulls in an encrypted manner, avoiding passwords and ensuring only authorized team members can interact with the repository.

### 🐳 Docker & Docker Compose (Isolated & Reproducible Environments)
* **What it is:** A containerization platform that packages applications and their dependencies together.
* **Why we use it:** It guarantees total consistency across all team members' computers. With a single command (`docker compose up`), we spin up the exact same infrastructure, databases, and services, ensuring the project runs identically everywhere.

### 🤖 Ollama (Local AI & LLM Execution)
* **What it is:** A lightweight framework designed to run Large Language Models locally on consumer hardware.
* **Why we use it:** It enables us to experiment with AI agents, retrieval-augmented generation (RAG), and local models (such as Qwen) directly on our local GPUs. This ensures complete data privacy, offline capability, and zero dependency on paid third-party APIs during development.

### 🌿 Git & GitHub Governance (Professional Workflow)
* **What it is:** Version control with protected branches and code review protocols.
* **Why we use it:** To ensure code quality and collaboration safety. We never commit directly to `main`; every feature is developed in isolation and requires peer review via Pull Requests before merging, mimicking real-world engineering teams.

## 👥 Team Roles & Responsibilities

| Member | Role | Key Technologies & Responsibilities |
| :--- | :--- | :--- |
| **Martim** | Backend & Infrastructure | Docker Compose, Ollama server setup, WireGuard VPN, Git repository management & PR reviews. |
| **Afonso** | Backend, Tests & CI/CD | Python micro-service (`/summarize` endpoint), automated testing, GitHub Actions CI. |
| **Lourenço** | Automation & Workflows | n8n daily email summary workflow (reading emails, invoking AI service, sending to Discord). |
| **Carlos** | Testing, Risk & Docs | Threat modeling, security & credential risk registry, n8n test cases, and README documentation. |
| **Dani** | Data & Backend | PostgreSQL database schema for execution logs, Grafana monitoring dashboards, synthetic pricing rules. |

---
