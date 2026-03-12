#!/usr/bin/env bash
# Restaurant Finder + React Shell. Agent: 10002. Client: http://localhost:5003

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

if [[ -z "$OPENAI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

cd "$ROOT/samples/agent/adk/restaurant_finder"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Restaurant Agent (port 10002)..."
uv run . --port 10002 &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting React Shell..."
cd "$ROOT/samples/client/react/shell"
npm run dev
