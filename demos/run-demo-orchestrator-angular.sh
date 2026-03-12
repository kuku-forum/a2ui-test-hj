#!/usr/bin/env bash
# Orchestrator + Angular. Agent: 10002. Uses Gemini.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "Set GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

cd "$ROOT/samples/agent/adk/orchestrator"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Orchestrator Agent (port 10002). Log: $DEMOS_ROOT/logs/orchestrator-angular-agent.log"
uv run . --port 10002 2>&1 | tee "$DEMOS_ROOT/logs/orchestrator-angular-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Angular (orchestrator). Log: $DEMOS_ROOT/logs/orchestrator-angular-client.log"
cd "$ROOT/samples/client/angular"
npm run start -- orchestrator 2>&1 | tee "$DEMOS_ROOT/logs/orchestrator-angular-client.log"
