#!/usr/bin/env bash
# Source demos/.env and set LITELLM_MODEL from GPT_MODEL or GEMINI_MODEL.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/scripts/load-env.sh"   (from demos/)
#    or: source "$DEMOS_ROOT/scripts/load-env.sh"
#
# 학습 포인트:
# - 우선순위: LITELLM_MODEL 직접 지정 > GPT_MODEL/GEMINI_MODEL 자동 변환
# - 즉, 모델 디버깅 시 최종적으로 export된 LITELLM_MODEL 값을 확인하는 게 핵심.

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
