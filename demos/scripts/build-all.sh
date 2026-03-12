#!/usr/bin/env bash
# Build all renderers and clients needed for demos. Run from repo root or demos/.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
cd "$ROOT"

echo ">>> Building renderers (web_core, markdown-it, lit, react)..."
cd "$ROOT/renderers/web_core"
npm install && npm run build

cd "$ROOT/renderers/markdown/markdown-it"
npm install && npm run build

cd "$ROOT/renderers/lit"
npm install && npm run build

cd "$ROOT/renderers/react"
npm install && npm run build

echo ">>> Building Lit shell client..."
cd "$ROOT/samples/client/lit/shell"
npm install && npm run build

echo ">>> Building React shell client..."
cd "$ROOT/samples/client/react/shell"
npm install && npm run build

echo ">>> Build complete. Use run-demo-*.sh to start demos."
