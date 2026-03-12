#!/usr/bin/env bash
# Contact Multiple Surfaces + Lit contact client. Agent: 10004. Open client URL for custom components demo.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$OPENAI_API_KEY" && -z "$GEMINI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY or GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

if lsof -ti:10004 >/dev/null 2>&1; then
  echo ">>> Port 10004 is in use. Stop the other demo (Ctrl+C there) or run: lsof -ti:10004 | xargs kill"
  exit 1
fi

cd "$ROOT/samples/agent/adk/contact_multiple_surfaces"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Contact Multiple Agent (port 10004). Log: $DEMOS_ROOT/logs/contact-multiple-lit-agent.log"
uv run . --port 10004 2>&1 | tee "$DEMOS_ROOT/logs/contact-multiple-lit-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Lit Contact client. Log: $DEMOS_ROOT/logs/contact-multiple-lit-client.log"
cd "$ROOT/samples/client/lit/contact"
npm install --quiet 2>/dev/null || true
npm run dev 2>&1 | tee "$DEMOS_ROOT/logs/contact-multiple-lit-client.log"
