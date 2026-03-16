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

# FLUTTER_DEVICE=android     → 연결된 첫 번째 Android 기기 자동 감지
# FLUTTER_DEVICE=RF8XN3J1H2T → 특정 기기 ID 직접 사용
# 에뮬레이터면 10.0.2.2, 실물 기기면 호스트 LAN IP 로 AGENT_URL 을 설정한다.
_set_agent_url() {
  local device_line="$1"
  if echo "$device_line" | grep -qi "emulator"; then
    DART_DEFINES="--dart-define=AGENT_URL=http://10.0.2.2:10002"
  else
    local host_ip
    host_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
    host_ip="${host_ip:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
    if [[ -n "$host_ip" ]]; then
      echo ">>> 실물 기기 감지. 에이전트 URL: http://$host_ip:10002"
      DART_DEFINES="--dart-define=AGENT_URL=http://$host_ip:10002"
    else
      echo ">>> WARNING: 호스트 IP 감지 실패. 필요 시 AGENT_URL 을 직접 설정하세요."
    fi
  fi
}

resolve_device() {
  DART_DEFINES=""
  [[ -z "${FLUTTER_DEVICE:-}" ]] && return
  local line
  if [[ "$FLUTTER_DEVICE" =~ ^[Aa]ndroid$ ]]; then
    line=$(flutter devices 2>/dev/null | grep -iE "android|mobile" | head -1)
    if [[ -z "$line" ]]; then
      echo ">>> 연결된 Android 기기가 없습니다. 'flutter devices' 로 확인하세요."
      flutter devices 2>/dev/null
      exit 1
    fi
    local id
    id=$(echo "$line" | sed 's/ • /•/g' | awk -F'•' '{print $2}' | xargs)
    echo ">>> 감지된 기기: $line"
    echo ">>> 사용할 기기 ID: $id"
    FLUTTER_DEVICE="$id"
  else
    # 특정 기기 ID → flutter devices 에서 해당 기기 정보 조회
    line=$(flutter devices 2>/dev/null | grep "$FLUTTER_DEVICE" | head -1)
  fi
  _set_agent_url "$line"
}

mkdir -p "$DEMOS_ROOT/logs"
LOG_FILE="$DEMOS_ROOT/logs/restaurant-flutter-client.log"
echo ">>> Flutter Restaurant Shell only. Log: $LOG_FILE"
echo ">>> Ensure agent is running (e.g. ./scripts/run-agent-restaurant.sh in another terminal)."
cd "$ROOT/samples/client/flutter/restaurant_shell"
flutter pub get
resolve_device
if [[ -n "${FLUTTER_DEVICE:-}" ]]; then
  flutter run -d "$FLUTTER_DEVICE" $DART_DEFINES 2>&1 | tee "$LOG_FILE"
elif flutter devices 2>/dev/null | grep -q "Chrome"; then
  flutter run -d chrome 2>&1 | tee "$LOG_FILE"
else
  flutter run $DART_DEFINES 2>&1 | tee "$LOG_FILE"
fi
