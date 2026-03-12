#!/usr/bin/env bash
# Contact Lookup + Angular. Agent: 10003.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$OPENAI_API_KEY" && -z "$GEMINI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY or GEMINI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

if lsof -ti:10003 >/dev/null 2>&1; then
  echo ">>> Port 10003 is in use. Stop the other demo (Ctrl+C there) or run: lsof -ti:10003 | xargs kill"
  exit 1
fi

cd "$ROOT/samples/agent/adk/contact_lookup"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Contact Agent (port 10003). Log: $DEMOS_ROOT/logs/contact-angular-agent.log"
uv run . --port 10003 2>&1 | tee "$DEMOS_ROOT/logs/contact-angular-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

echo ">>> Starting Angular (contact). Log: $DEMOS_ROOT/logs/contact-angular-client.log"
cd "$ROOT/samples/client/angular"
npm install --quiet 2>/dev/null || true
npm run start -- contact 2>&1 | tee "$DEMOS_ROOT/logs/contact-angular-client.log"
