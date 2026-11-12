# Team Onboarding & Local Setup Guide

Welcome to the project! This guide covers everything you need to install and configure on your machine so we can all work with the exact same environment and workflow.

---

## 🛠️ 1. Prerequisites Checklist

Depending on your OS, follow the steps below:

### For Windows Users (WSL2 Setup)
We run all code and containers inside **WSL2 (Ubuntu)** to avoid Windows path issues and ensure cross-platform compatibility.

1. **Enable & Install WSL2:**
   Open PowerShell as Administrator and run:
   ```powershell
   wsl --install
   ```
2. **Reboot your computer** if prompted.
3. **Setup Ubuntu:**
   After restarting, Ubuntu will open automatically. Set up your UNIX username and password (keep note of this password).
4. **Update packages inside Ubuntu:**
   Open your Ubuntu terminal and run:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y git curl build-essential
   ```

---

## 🐳 2. Docker & Docker Compose Setup

### Windows / macOS:
1. Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. **For Windows:** During installation, ensure **"Use WSL 2 instead of Hyper-V"** is checked.
3. Open Docker Desktop settings:
   * Go to **Settings > Resources > WSL Integration**.
   * Turn on integration for your `Ubuntu` distribution.
4. Open your Ubuntu terminal and verify it works:
   ```bash
   docker --version
   docker compose version
   ```

### Linux (Native):
```bash
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
# Log out and log back in for group permissions to apply
```

---

## 🔑 3. Git & GitHub Setup

Execute these commands inside your **WSL2 / Linux terminal**:

1. **Configure Git identity:**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **Generate SSH Key (Recommended for GitHub authentication):**
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```
   * Press Enter to accept default location, and set a passphrase when asked (recommended).
   * Print your key and copy it:
     ```bash
     cat ~/.ssh/id_ed25519.pub
     ```
   * Go to **GitHub Settings > SSH and GPG keys > New SSH Key**, and paste the content.

3. **Clone the Repository:**
   ```bash
   git clone git@github.com:AfonsoSousaDEV/homelab-hub.git
   cd homelab-hub
   ```
   Clone it inside the Ubuntu filesystem (for example `~/projects`), not under `/mnt/c/...`: it is much faster and avoids permission problems.

---

## 🤖 4. Local AI Environment (Ollama Setup)

Ollama runs as a container in our `compose.yaml`, so everyone gets the same version and nothing is installed globally. You do not need to install it separately.

1. **Start the stack and download a light model** (Phi-4 Mini / Qwen 3 4B fit in 6 GB of VRAM):
   ```bash
   ./scripts/init-env.sh
   docker compose up -d
   ./scripts/pull-model.sh qwen3:4b
   docker compose exec ollama ollama run qwen3:4b
   ```
2. **NVIDIA GPU (optional):** set `COMPOSE_FILE=compose.yaml:compose.gpu.yaml` in `.env` and run `docker compose up -d` again. On Windows the NVIDIA driver is installed on Windows itself, not inside Ubuntu; `nvidia-smi` should work inside Ubuntu if everything is right.
3. **Verify GPU offloading:**
   ```bash
   docker compose exec ollama ollama ps
   ```
   The `PROCESSOR` column should say `100% GPU`. If it shows CPU, close other GPU-heavy apps (browser, games) and keep the context small (`OLLAMA_CONTEXT_LENGTH` in `.env`).
4. **Machines without a GPU** work too, only slower. Skip step 2.

Optional: you can also install Ollama natively inside Ubuntu (`curl -fsSL https://ollama.com/install.sh | sh`), but do not run it at the same time as the container, because both use port 11434.

---

## 🤝 5. Group Workflow & Contribution Rules

To keep the repository clean and ensure everyone reviews code:

1. **Never commit directly to `main`.**
2. **Create a branch for every task:**
   ```bash
   git checkout -b feature/your-task-name
   ```
3. **Commit with clear messages:**
   ```bash
   git commit -m "feat: add user authentication endpoint"
   ```
4. **Push and create a Pull Request (PR):**
   ```bash
   git push origin feature/your-task-name
   ```
5. **PR Rule:** Self-merging is disabled. At least one teammate must review and approve your PR before merging!

This is enforced by a GitHub ruleset on `main`: pull request required, 1 approval, no force-push, no branch deletion. If a push to `main` is rejected, that is the rule working, not a bug.

---

## ⚡ Quick Test (Verification)

Run these commands inside the project root directory (in Ubuntu):
```bash
./scripts/init-env.sh
docker compose up -d
docker compose ps
```
All three services (`postgres`, `n8n`, `ollama`) should show as running, and `postgres` as `healthy`. Open http://localhost:5678 to see n8n. If that works, your setup is ready.

Stop everything with `docker compose down` (your data stays in Docker volumes; `docker compose down -v` deletes it).