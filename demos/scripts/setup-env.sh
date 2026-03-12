#!/usr/bin/env bash
# Create demos/.env from .env.example if missing. Run from demos/ or repo root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$DEMOS_ROOT/.env"
EXAMPLE="$DEMOS_ROOT/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$EXAMPLE" "$ENV_FILE"
  echo "Created $ENV_FILE from .env.example. Edit it to set OPENAI_API_KEY, GPT_MODEL, etc."
else
  echo ".env already exists at $ENV_FILE"
fi
