#!/usr/bin/env bash
# Run only the Restaurant Finder agent (no client). Use in terminal 1; run client in terminal 2.
# Logs (A2A messages, surface updates) appear in this terminal.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

if [[ -z "$OPENAI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

mkdir -p "$DEMOS_ROOT/logs"
LOG_FILE="$DEMOS_ROOT/logs/restaurant-agent.log"
cd "$ROOT/samples/agent/adk/restaurant_finder"
uv sync --quiet 2>/dev/null || true
echo ">>> Restaurant Agent only (port 10002). Log: $LOG_FILE"
echo ">>> Start client in another terminal (e.g. ./scripts/run-client-lit.sh)."
uv run . --port 10002 2>&1 | tee "$LOG_FILE"
