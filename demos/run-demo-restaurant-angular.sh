#!/usr/bin/env bash
# Restaurant Finder + Angular. Agent: 10002. Client: Angular dev server.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$OPENAI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

cd "$ROOT/samples/agent/adk/restaurant_finder"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Restaurant Agent (port 10002). Log: $DEMOS_ROOT/logs/restaurant-angular-agent.log"
uv run . --port 10002 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-angular-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Angular (restaurant). Log: $DEMOS_ROOT/logs/restaurant-angular-client.log"
cd "$ROOT/samples/client/angular"
npm install --quiet 2>/dev/null || true
npm run start -- restaurant 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-angular-client.log"
