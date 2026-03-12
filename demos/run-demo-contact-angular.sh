#!/usr/bin/env bash
# Contact Lookup + Angular. Agent: 10003.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "Set GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

cd "$ROOT/samples/agent/adk/contact_lookup"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Contact Agent (port 10003)..."
uv run . --port 10003 &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Angular (contact project)..."
cd "$ROOT/samples/client/angular"
npm run start -- contact
