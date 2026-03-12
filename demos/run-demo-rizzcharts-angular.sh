#!/usr/bin/env bash
# Rizzcharts + Angular. Agent: 10002. Uses Gemini.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$OPENAI_API_KEY" && -z "$GEMINI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY or GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

if lsof -ti:10002 >/dev/null 2>&1; then
  echo ">>> Port 10002 is in use. Stop the other demo (Ctrl+C there) or run: lsof -ti:10002 | xargs kill"
  exit 1
fi

cd "$ROOT/samples/agent/adk/rizzcharts"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Rizzcharts Agent (port 10002). Log: $DEMOS_ROOT/logs/rizzcharts-angular-agent.log"
uv run . --port 10002 2>&1 | tee "$DEMOS_ROOT/logs/rizzcharts-angular-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Angular (rizzcharts). Log: $DEMOS_ROOT/logs/rizzcharts-angular-client.log"
cd "$ROOT/samples/client/angular"
npm install --quiet 2>/dev/null || true
npm run start -- rizzcharts 2>&1 | tee "$DEMOS_ROOT/logs/rizzcharts-angular-client.log"
