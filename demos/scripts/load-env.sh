#!/usr/bin/env bash
# Source demos/.env and set LITELLM_MODEL from GPT_MODEL or GEMINI_MODEL.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/scripts/load-env.sh"   (from demos/)
#    or: source "$DEMOS_ROOT/scripts/load-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"

export A2UI_DEMOS_ROOT="$DEMOS_ROOT"
export A2UI_ROOT="$ROOT"

if [[ -f "$DEMOS_ROOT/.env" ]]; then
  set -a
  # shellcheck source=../.env.example
  source "$DEMOS_ROOT/.env"
  set +a
  if [[ -z "$LITELLM_MODEL" ]]; then
    if [[ -n "$GPT_MODEL" ]]; then
      export LITELLM_MODEL="openai/$GPT_MODEL"
    elif [[ -n "$GEMINI_MODEL" ]]; then
      export LITELLM_MODEL="gemini/$GEMINI_MODEL"
    fi
  fi
fi
