#!/usr/bin/env bash
# Run only the Flutter Restaurant Shell client. Use in terminal 2; start agent first in terminal 1 (e.g. ./scripts/run-agent-restaurant.sh).
# Expects Restaurant Finder agent on http://localhost:10002.
#
# 학습 포인트:
# - Android 에뮬레이터는 host localhost를 직접 보지 못하므로 10.0.2.2를 사용한다.
# - "화면은 뜨는데 데이터가 안 보임" 문제는 대개 AGENT_URL/디바이스 매핑 이슈다.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"

# Flutter SDK 자동 탐색·설치 (없으면 자동 다운로드)
# shellcheck source=setup-flutter.sh
source "$SCRIPT_DIR/setup-flutter.sh"
if ! command -v flutter &>/dev/null; then
  echo "Flutter SDK 설치에 실패했습니다."
  echo "수동 설치: https://docs.flutter.dev/get-started/install"
  echo "또는 FLUTTER_ROOT 환경 변수를 SDK 경로로 설정하세요."
  exit 1
fi

mkdir -p "$DEMOS_ROOT/logs"
LOG_FILE="$DEMOS_ROOT/logs/restaurant-flutter-client.log"
echo ">>> Flutter Restaurant Shell only. Log: $LOG_FILE"
echo ">>> Ensure agent is running (e.g. ./scripts/run-agent-restaurant.sh in another terminal)."
cd "$ROOT/samples/client/flutter/restaurant_shell"
flutter pub get
# Android emulator: use 10.0.2.2 to reach host agent
DART_DEFINES=""
if [[ "$FLUTTER_DEVICE" == "android" ]]; then
  DART_DEFINES="--dart-define=AGENT_URL=http://10.0.2.2:10002"
fi
if [[ -n "$FLUTTER_DEVICE" ]]; then
  flutter run -d "$FLUTTER_DEVICE" $DART_DEFINES 2>&1 | tee "$LOG_FILE"
elif flutter devices 2>/dev/null | grep -q "Chrome"; then
  flutter run -d chrome 2>&1 | tee "$LOG_FILE"
else
  flutter run $DART_DEFINES 2>&1 | tee "$LOG_FILE"
fi
