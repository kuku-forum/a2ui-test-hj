#!/usr/bin/env bash
# Run the Restaurant Finder demo from the project root.
# Prerequisites: Node.js, Python 3.13+, uv, and OPENAI_API_KEY in .env.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# --- .env setup ---
RESTAURANT_ENV="$ROOT/samples/agent/adk/restaurant_finder/.env"
if [[ ! -f "$RESTAURANT_ENV" ]]; then
  if [[ -f "$ROOT/samples/agent/adk/restaurant_finder/.env.example" ]]; then
    cp "$ROOT/samples/agent/adk/restaurant_finder/.env.example" "$RESTAURANT_ENV"
    echo "Created $RESTAURANT_ENV from .env.example. Please set OPENAI_API_KEY and re-run."
    exit 1
  else
    echo "Missing .env. Create $RESTAURANT_ENV with OPENAI_API_KEY=your_key"
    exit 1
  fi
fi
if ! grep -q 'OPENAI_API_KEY=.\+' "$RESTAURANT_ENV" 2>/dev/null; then
  echo "OPENAI_API_KEY is not set in $RESTAURANT_ENV. Edit the file and re-run."
  exit 1
fi

# --- Backend (Python/uv) ---
echo ">>> Installing backend (restaurant_finder)..."
cd "$ROOT/samples/agent/adk/restaurant_finder"
if ! command -v uv &>/dev/null; then
  echo "uv is required. Install: https://docs.astral.sh/uv/getting-started/installation/"
  exit 1
fi
uv sync

# --- Frontend: build order web_core -> markdown-it, lit -> shell ---
echo ">>> Installing and building frontend..."

cd "$ROOT/renderers/web_core"
npm install
npm run build

cd "$ROOT/renderers/markdown/markdown-it"
npm install
npm run build

cd "$ROOT/renderers/lit"
npm install
npm run build

cd "$ROOT/samples/client/lit/shell"
npm install
npm run build

# --- Run backend in background, then frontend ---
echo ">>> Starting backend (Agent) on http://localhost:10002 ..."
cd "$ROOT/samples/agent/adk/restaurant_finder"
uv run . &
BACKEND_PID=$!
trap "kill $BACKEND_PID 2>/dev/null" EXIT

sleep 3

echo ">>> Starting frontend (Shell client)..."
cd "$ROOT/samples/client/lit/shell"
npm run dev
