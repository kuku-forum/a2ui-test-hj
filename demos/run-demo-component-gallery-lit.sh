#!/usr/bin/env bash
# Component Gallery + Lit client. Agent: 10005. No LLM/API key required.
# If component_gallery agent has no pyproject, run the client only (or start agent manually).

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

CG_AGENT="$ROOT/samples/agent/adk/component_gallery"
if [[ -f "$CG_AGENT/pyproject.toml" ]]; then
  cd "$CG_AGENT"
  uv sync --quiet 2>/dev/null || true
  echo ">>> Starting Component Gallery Agent (port 10005)..."
  uv run . --port 10005 &
  PID=$!
  trap "kill $PID 2>/dev/null" EXIT
  sleep 3
else
  echo ">>> Component Gallery agent has no pyproject; start it manually from $CG_AGENT if needed."
fi

echo ">>> Starting Lit Component Gallery client..."
cd "$ROOT/samples/client/lit/component_gallery"
npm install --quiet 2>/dev/null || true
npm run dev
