# homelab-hub project
A lightweight homelab dashboard and automation utility for our team project.

## 🧠 Architectural & Tech Stack Overview

To achieve our goals of building a robust portfolio, exploring local AI (LLMs), and adopting professional software engineering practices[cite: 1], our team relies on a standardized, open-source technology stack. Here is why we use each component:

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
* **Why we use it:** It guarantees total consistency across all team members' computers. With a single command (`docker compose up`), we spin up the exact same infrastructure, databases, and services, ensuring the project runs identically everywhere[cite: 1, 2].

### 🤖 Ollama (Local AI & LLM Execution)
* **What it is:** A lightweight framework designed to run Large Language Models locally on consumer hardware[cite: 1, 3].
* **Why we use it:** It enables us to experiment with AI agents, retrieval-augmented generation (RAG), and local models (such as Qwen) directly on our local GPUs[cite: 1, 3]. This ensures complete data privacy, offline capability, and zero dependency on paid third-party APIs during development[cite: 1].

### 🌿 Git & GitHub Governance (Professional Workflow)
* **What it is:** Version control with protected branches and code review protocols[cite: 2, 5].
* **Why we use it:** To ensure code quality and collaboration safety. We never commit directly to `main`; every feature is developed in isolation and requires peer review via Pull Requests before merging, mimicking real-world engineering teams[cite: 2, 5].

## 🧠 Architectural & Tech Stack Overview

To achieve our goals of building a robust portfolio, exploring local AI (LLMs), and adopting professional software engineering practices[cite: 1], our team relies on a standardized, open-source technology stack:

- **Ubuntu & WSL2**: The standardized development environment.
- **Docker & Docker Compose**: Containerized infrastructure for n8n, PostgreSQL, and Grafana.
- **Ollama**: Centralized AI model execution hosted on dedicated team hardware (Branco's machine).
- **WireGuard**: Secure private VPN access across team members.

---

## 👥 Team Roles & Responsibilities

| Member | Role | Key Technologies & Responsibilities |
| :--- | :--- | :--- |
| **Martim** | Backend & Infrastructure[cite: 6] | Docker Compose, Ollama server setup, WireGuard VPN, Git repository management & PR reviews[cite: 10]. |
| **Afonso** | Backend, Tests & CI/CD[cite: 6] | Python micro-service (`/summarize` endpoint), automated testing, GitHub Actions CI[cite: 10]. |
| **Lourenço** | Automation & Workflows[cite: 6, 10] | n8n daily email summary workflow (reading emails, invoking AI service, sending to Discord)[cite: 10]. |
| **Carlos** | Testing, Risk & Docs[cite: 6, 10] | Threat modeling, security & credential risk registry, n8n test cases, and README documentation[cite: 10]. |
| **Dani** | Data & Backend[cite: 6, 10] | PostgreSQL database schema for execution logs, Grafana monitoring dashboards, synthetic pricing rules[cite: 10]. |

---
