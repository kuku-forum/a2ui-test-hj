#!/usr/bin/env bash
# Flutter Restaurant Shell 클라이언트만 실행.
# 에이전트는 터미널 1에서 먼저 실행하세요: ./scripts/run-agent-restaurant.sh
# Expects Restaurant Finder agent on http://localhost:10002.
#
# 사용법:
#   ./scripts/run-client-flutter-shell.sh                  → Chrome (웹) 또는 Android 자동 감지
#   FLUTTER_DEVICE=android ./scripts/run-client-flutter-shell.sh    → Android 기기 자동 감지
#   FLUTTER_DEVICE=RF8XN3J1H2T ./scripts/run-client-flutter-shell.sh → 특정 기기 ID
#
# 학습 포인트:
# - Android 에뮬레이터는 host localhost를 직접 보지 못하므로 10.0.2.2를 사용한다.
# - 실물 기기는 호스트 PC의 LAN IP를 사용한다 (자동 감지).
# - "화면은 뜨는데 데이터가 안 보임" 문제는 대개 AGENT_URL/디바이스 매핑 이슈다.

set -e
# setup-flutter.sh 가 set -euo pipefail 을 전파하므로 미리 초기화
DART_DEFINES=""
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

# ── Flutter 디바이스 감지 및 AGENT_URL 설정 ────────────────────────────────────
# String.fromEnvironment 는 컴파일 타임 상수이므로 --dart-define 으로 주입한다.
# 실물 기기는 PC의 LAN IP, 에뮬레이터는 10.0.2.2, 웹은 localhost 를 사용한다.

# adb reverse 두 포트 모두 포워딩. 성공 시 0, 실패(adb 없음·기기 미연결 등) 시 1 반환.
_adb_reverse() {
  command -v adb &>/dev/null           || return 1
  adb reverse tcp:10002 tcp:10002 2>/dev/null || return 1
  adb reverse tcp:10003 tcp:10003 2>/dev/null || return 1
}

_set_agent_url() {
  local device_line="$1"
  local agent_host
  if echo "$device_line" | grep -qi "emulator"; then
    agent_host="10.0.2.2"
    echo ">>> 에뮬레이터 감지. 에이전트 URL: http://$agent_host:10002"
  else
    # adb reverse 성공 → localhost 사용 (가장 안정적).
    # 실패 시 → PC LAN IP로 폴백 (Wi-Fi 같은 네트워크 필요).
    if _adb_reverse; then
      agent_host="localhost"
      echo ">>> [adb reverse] 포트 포워딩 성공 → 폰에서 localhost:10002 사용"
    else
      echo ">>> [adb reverse 실패] LAN IP로 폴백"
      agent_host=$(ip route get 8.8.8.8 2>/dev/null \
        | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
      agent_host="${agent_host:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
      if [[ -z "$agent_host" ]]; then
        echo ">>> WARNING: 호스트 IP 감지 실패."
        echo ">>>   USB 연결 후 adb reverse 또는 AGENT_URL=http://<IP>:10002 직접 지정"
        return
      fi
      echo ">>> 실물 기기 감지. LAN IP 에이전트 URL: http://$agent_host:10002"
    fi
  fi
  DART_DEFINES="--dart-define=AGENT_URL=http://$agent_host:10002 --dart-define=CONTACTS_AGENT_URL=http://$agent_host:10003"
}

resolve_device() {
  DART_DEFINES=""
  local devices_output
  devices_output=$(flutter devices 2>/dev/null)

  if [[ -z "${FLUTTER_DEVICE:-}" ]]; then
    local android_line
    android_line=$(echo "$devices_output" | grep -iE "android|mobile" | head -1)
    if [[ -n "$android_line" ]]; then
      local id
      id=$(echo "$android_line" | sed 's/ • /•/g' | awk -F'•' '{print $2}' | xargs)
      echo ">>> Android 기기 자동 감지: $android_line"
      echo ">>> 사용할 기기 ID: $id"
      FLUTTER_DEVICE="$id"
      _set_agent_url "$android_line"
    else
      echo ">>> Android 기기 없음 → Chrome(웹)으로 실행합니다."
      FLUTTER_DEVICE="chrome"
    fi
    return
  fi

  local line
  if [[ "$FLUTTER_DEVICE" =~ ^[Aa]ndroid$ ]]; then
    line=$(echo "$devices_output" | grep -iE "android|mobile" | head -1)
    if [[ -z "$line" ]]; then
      echo ">>> 연결된 Android 기기가 없습니다. 'flutter devices' 로 확인하세요."
      echo "$devices_output"
      exit 1
    fi
    local id
    id=$(echo "$line" | sed 's/ • /•/g' | awk -F'•' '{print $2}' | xargs)
    echo ">>> 감지된 기기: $line"
    echo ">>> 사용할 기기 ID: $id"
    FLUTTER_DEVICE="$id"
  else
    line=$(echo "$devices_output" | grep "$FLUTTER_DEVICE" | head -1)
  fi
  _set_agent_url "$line"
}

# ── Flutter 클라이언트 실행 ─────────────────────────────────────────────────────
mkdir -p "$DEMOS_ROOT/logs"
LOG="$DEMOS_ROOT/logs/restaurant-flutter-client.log"
echo ">>> Flutter Restaurant Shell only. Log: $LOG"
echo ">>> Ensure agent is running (터미널 1: ./scripts/run-agent-restaurant.sh)."
cd "$ROOT/samples/client/flutter/restaurant_shell"
# flutter pub get: 출력 캡처 후 meta override 관련 cosmetic 경고 라인만 제거
_pub_out=$(flutter pub get 2>&1) || {
  echo "$_pub_out"
  echo ">>> [ERROR] flutter pub get 실패. 위 오류를 확인하세요."
  exit 1
}
echo "$_pub_out" | grep -vE "(newer versions incompatible|Try.*pub outdated|overridden)" || true

resolve_device

echo ">>> FLUTTER_DEVICE=$FLUTTER_DEVICE"
if [[ "$FLUTTER_DEVICE" == "chrome" ]]; then
  # 웹: web-server 모드로 실행 → Chrome·Edge 등 어떤 브라우저에서도 접속 가능.
  # VSCode Remote 사용 시 포트 포워딩 후 로컬 브라우저로 접속.
  WEB_PORT="${FLUTTER_WEB_PORT:-8080}"
  echo ">>> 웹 서버 모드: http://localhost:$WEB_PORT"
  echo ">>> Edge·Chrome 등 브라우저에서 위 주소를 여세요."
  # tee 파이프 금지: flutter run은 TTY가 없으면 즉시 종료됨
  flutter run -d web-server --web-port "$WEB_PORT" $DART_DEFINES
else
  echo ">>> 릴리즈 모드로 실행합니다 (debug 대비 성능 대폭 개선)."
  flutter run -d "$FLUTTER_DEVICE" --release $DART_DEFINES 2>&1 | tee "$LOG"
fi
