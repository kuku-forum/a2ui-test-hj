#!/usr/bin/env bash
# Contact Multiple Surfaces + Lit contact client. Agent: 10004. Open client URL for custom components demo.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "Set GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

cd "$ROOT/samples/agent/adk/contact_multiple_surfaces"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Contact Multiple Surfaces Agent (port 10004)..."
uv run . --port 10004 &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Lit Contact client (connects to 10004)..."
cd "$ROOT/samples/client/lit/contact"
npm install --quiet 2>/dev/null || true
npm run dev
