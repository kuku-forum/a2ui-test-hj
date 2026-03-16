#!/usr/bin/env bash
# Restaurant Finder + Flutter (Lit-style: chat input + A2UI). Agent: 10002.
# Web: Chrome. Android: use FLUTTER_DEVICE=android or -d android when run separately.
#
# 학습 포인트:
# - 한 스크립트 안에서 agent/client를 모두 띄운다.
# - 실패 원인 분리는 어렵지만, "빠르게 전체 동작 확인"에는 가장 편하다.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

FLUTTER_SHELL="$ROOT/samples/client/flutter/restaurant_shell"
mkdir -p "$DEMOS_ROOT/logs"

if [[ -z "$OPENAI_API_KEY" ]] || [[ "$OPENAI_API_KEY" == *"your_openai"* ]]; then
  echo "Set OPENAI_API_KEY in $DEMOS_ROOT/.env"
  exit 1
fi

# Flutter SDK 자동 탐색·설치 (없으면 자동 다운로드)
# shellcheck source=scripts/setup-flutter.sh
source "$DEMOS_ROOT/scripts/setup-flutter.sh"
if ! command -v flutter &>/dev/null; then
  echo "Flutter SDK 설치에 실패했습니다."
  echo "수동 설치: https://docs.flutter.dev/get-started/install"
  echo "또는 FLUTTER_ROOT 환경 변수를 SDK 경로로 설정하세요."
  exit 1
fi

if lsof -ti:10002 >/dev/null 2>&1; then
  echo ">>> Port 10002 is in use. Stop the other demo (Ctrl+C there) or run: lsof -ti:10002 | xargs kill"
  exit 1
fi

# Start agent (log to file and terminal)
cd "$ROOT/samples/agent/adk/restaurant_finder"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Restaurant Agent (port 10002). Log: $DEMOS_ROOT/logs/restaurant-agent.log"
uv run . --port 10002 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

# Run Flutter client (web or Android via FLUTTER_DEVICE)
echo ">>> Starting Flutter Restaurant Shell. Log: $DEMOS_ROOT/logs/restaurant-flutter-client.log"
cd "$FLUTTER_SHELL"
flutter pub get
# On Android emulator, localhost is the emulator; use 10.0.2.2 to reach host.
DART_DEFINES=""
if [[ "$FLUTTER_DEVICE" == "android" ]]; then
  DART_DEFINES="--dart-define=AGENT_URL=http://10.0.2.2:10002"
fi
if [[ -n "$FLUTTER_DEVICE" ]]; then
  flutter run -d "$FLUTTER_DEVICE" $DART_DEFINES 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-flutter-client.log"
elif flutter devices 2>/dev/null | grep -q "Chrome"; then
  flutter run -d chrome 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-flutter-client.log"
else
  echo "Available devices:"
  flutter devices
  flutter run $DART_DEFINES 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-flutter-client.log"
fi
