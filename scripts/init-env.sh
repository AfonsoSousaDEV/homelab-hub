#!/usr/bin/env bash
# Creates .env from .env.example and fills in random secrets.
# Refuses to overwrite an existing .env.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env already exists, not touching it." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required (sudo apt install -y openssl)." >&2
  exit 1
fi

cp .env.example .env
db_password="$(openssl rand -hex 24)"
encryption_key="$(openssl rand -hex 32)"
api_key="$(openssl rand -hex 32)"

sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${db_password}|" .env
sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${encryption_key}|" .env
sed -i "s|^API_KEY=.*|API_KEY=${api_key}|" .env

echo ".env created. Back up N8N_ENCRYPTION_KEY somewhere safe (not in git)."
echo "NVIDIA GPU? Set COMPOSE_FILE=compose.yaml:compose.gpu.yaml in .env."
