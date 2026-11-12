#!/usr/bin/env bash
# Import every workflow JSON in ./workflows into your local n8n (e.g. after a git pull).
set -euo pipefail
export MSYS_NO_PATHCONV=1  # stop Git Bash on Windows from rewriting /workflows paths
cd "$(dirname "$0")/.."
docker compose exec n8n n8n import:workflow --separate --input=/workflows/
echo "Imported. Reconnect your own credentials in the n8n UI if a workflow needs them."
