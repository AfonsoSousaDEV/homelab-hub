#!/usr/bin/env bash
# Downloads a model into the running Ollama container.
# Usage: ./scripts/pull-model.sh [model]   (default: qwen3:4b)
set -euo pipefail

cd "$(dirname "$0")/.."

model="${1:-qwen3:4b}"
docker compose exec ollama ollama pull "$model"
echo "Done. Check GPU offloading with: docker compose exec ollama ollama ps"
