#!/usr/bin/env bash
# Orchestrator + Angular. Agent: 10002. Uses Gemini.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "Set GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

cd "$ROOT/samples/agent/adk/orchestrator"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Orchestrator Agent (port 10002)..."
uv run . --port 10002 &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Angular (orchestrator project)..."
cd "$ROOT/samples/client/angular"
npm run start -- orchestrator
