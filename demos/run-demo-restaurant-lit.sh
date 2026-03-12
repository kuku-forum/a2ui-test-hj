#!/usr/bin/env bash
# Restaurant Finder + Lit Shell. Agent: 10002. Client: http://localhost:5173

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$OPENAI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

if lsof -ti:10002 >/dev/null 2>&1; then
  echo ">>> Port 10002 is in use. Stop the other demo (Ctrl+C there) or run: lsof -ti:10002 | xargs kill"
  exit 1
fi

cd "$ROOT/samples/agent/adk/restaurant_finder"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Restaurant Agent (port 10002). Log: $DEMOS_ROOT/logs/restaurant-lit-agent.log"
uv run . --port 10002 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-lit-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Lit Shell. Log: $DEMOS_ROOT/logs/restaurant-lit-client.log"
cd "$ROOT/samples/client/lit/shell"
npm install --quiet 2>/dev/null || true
npm run dev 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-lit-client.log"
