#!/usr/bin/env bash
# One-time setup for the n8n email digest. Safe to run again.
# Creates .env, starts n8n, imports the workflow and checks that Ollama is reachable.
set -euo pipefail
export MSYS_NO_PATHCONV=1  # stop Git Bash on Windows from rewriting container paths
cd "$(dirname "$0")/.."

ok()   { echo "✔ $*"; }
warn() { echo "⚠ $*"; }
fail() { echo "❌ $*"; exit 1; }

rand() { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# set_env KEY VALUE -> writes KEY=VALUE into .env (replaces or appends)
set_env() {
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
get_env() { grep "^$1=" .env | head -1 | cut -d= -f2- || true; }

# 1. Docker running?
docker info >/dev/null 2>&1 || fail "Docker isn't running. Open Docker Desktop, wait until it says 'Engine running', then run this again."

# 2. .env with random passwords
if [ ! -f .env ]; then
  cp .env.example .env
  set_env POSTGRES_PASSWORD "$(rand)"
  set_env N8N_ENCRYPTION_KEY "$(rand)"
  ok "Created .env with random passwords"
else
  ok ".env already exists, keeping it"
fi

# 3. Discord webhook
if [[ "$(get_env DISCORD_WEBHOOK_URL)" != https://* ]]; then
  echo
  echo "Paste your Discord webhook URL and press Enter (guide step 1):"
  read -r url || url=""
  if [[ "$url" == https://discord.com/api/webhooks/* || "$url" == https://discordapp.com/api/webhooks/* ]]; then
    set_env DISCORD_WEBHOOK_URL "$url"
    ok "Saved Discord webhook"
  else
    warn "That doesn't look like a Discord webhook URL. Skipped. Run this script again to add it."
  fi
fi

# 4. Start n8n
docker compose up -d --quiet-pull >/dev/null 2>&1 || docker compose up -d
echo -n "Waiting for n8n to start"
for _ in $(seq 1 60); do
  if curl -sf http://localhost:5678/healthz >/dev/null 2>&1; then break; fi
  echo -n "."; sleep 2
done
echo
curl -sf http://localhost:5678/healthz >/dev/null 2>&1 || fail "n8n didn't start. See: docker compose logs n8n"
ok "n8n is running at http://localhost:5678"

# 5. Import the workflows (only the first time, so your Gmail connection isn't reset)
if docker compose exec -T n8n n8n list:workflow 2>/dev/null | grep -q "EmailDigest00001"; then
  ok "Workflow already imported"
else
  docker compose exec -T n8n n8n import:workflow --separate --input=/workflows/ >/dev/null 2>&1 \
    || fail "Could not import the workflow. See: docker compose logs n8n"
  ok "Imported workflow 'Email digest → Discord'"
fi

# 6. Can n8n reach Ollama?
model="$(get_env OLLAMA_MODEL)"; model="${model:-qwen3:4b}"
models="$(docker compose exec -T n8n node -e \
  "fetch(process.env.OLLAMA_URL+'/api/tags').then(r=>r.json()).then(j=>console.log(j.models.map(m=>m.name).join(' '))).catch(()=>process.exit(1))" \
  2>/dev/null)" || models="UNREACHABLE"

if [ "$models" = "UNREACHABLE" ]; then
  warn "n8n can't reach Ollama. See 'If something goes wrong' in docs/n8n-email-digest.md"
elif [[ " $models " != *" $model "* ]]; then
  warn "Ollama works but the model '$model' isn't downloaded. Run:  ollama pull $model"
else
  ok "Ollama is reachable and '$model' is ready"
fi

echo
echo "Next: open http://localhost:5678 and continue with step 3 of the guide."
