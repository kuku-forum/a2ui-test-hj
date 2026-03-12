#!/usr/bin/env bash
# Run only the Lit Shell client. Use in terminal 2; start agent first in terminal 1 (e.g. ./scripts/run-agent-restaurant.sh).
# Expects Restaurant Finder agent on http://localhost:10002.
#
# 학습 포인트:
# - 클라이언트만 실행할 때는 CORS/포트/에이전트 실행 여부를 분리해서 확인하기 쉽다.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"

mkdir -p "$DEMOS_ROOT/logs"
LOG_FILE="$DEMOS_ROOT/logs/restaurant-lit-client.log"
echo ">>> Lit Shell only. Log: $LOG_FILE"
echo ">>> Ensure agent is running (e.g. ./scripts/run-agent-restaurant.sh in another terminal)."
cd "$ROOT/samples/client/lit/shell"
npm run dev 2>&1 | tee "$LOG_FILE"
