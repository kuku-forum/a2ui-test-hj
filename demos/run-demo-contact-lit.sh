#!/usr/bin/env bash
# Contact Lookup + Lit Shell. Agent: 10003. Open http://localhost:5173 and click "Contacts" at the top.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "Set GEMINI_API_KEY in $DEMOS_ROOT/.env (Contact sample requires Gemini)"
  exit 1
fi

if lsof -ti:10003 >/dev/null 2>&1; then
  echo ">>> Port 10003 is in use. Stop the other demo (Ctrl+C there) or run: lsof -ti:10003 | xargs kill"
  exit 1
fi

cd "$ROOT/samples/agent/adk/contact_lookup"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Contact Agent (port 10003). Log: $DEMOS_ROOT/logs/contact-lit-agent.log"
uv run . --port 10003 2>&1 | tee "$DEMOS_ROOT/logs/contact-lit-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Lit Shell. Open http://localhost:5173 then click 'Contacts' at the top. Log: $DEMOS_ROOT/logs/contact-lit-client.log"
cd "$ROOT/samples/client/lit/shell"
npm install --quiet 2>/dev/null || true
npm run dev 2>&1 | tee "$DEMOS_ROOT/logs/contact-lit-client.log"
