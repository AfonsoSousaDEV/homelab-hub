#!/usr/bin/env bash
# Export every workflow from your local n8n into ./workflows (one JSON file each), ready to commit.
set -euo pipefail
export MSYS_NO_PATHCONV=1  # stop Git Bash on Windows from rewriting /workflows paths
cd "$(dirname "$0")/.."
docker compose exec n8n n8n export:workflow --all --separate --pretty --output=/workflows/
echo "Exported to ./workflows - review with 'git diff' before committing."
