#!/usr/bin/env bash
# Restaurant Finder + Flutter (에이전트 + 클라이언트 한 번에 실행).
# Agent port: 10002. Flutter: Chrome(기본) 또는 연결된 Android 기기.
#
# 사용법:
#   ./run-demo-restaurant-flutter.sh                  → Chrome (웹)
#   FLUTTER_DEVICE=android ./run-demo...              → Android 기기 자동 감지
#   FLUTTER_DEVICE=RF8XN3J1H2T ./run-demo...          → 특정 기기 ID
#
# 학습 포인트:
# - 한 스크립트 안에서 agent/client를 모두 띄운다.
# - 실패 원인 분리는 어렵지만, "빠르게 전체 동작 확인"에는 가장 편하다.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEMOS_ROOT/.." && pwd)"
source "$DEMOS_ROOT/scripts/load-env.sh"

FLUTTER_SHELL="$ROOT/samples/client/flutter/restaurant_shell"
LOG="$DEMOS_ROOT/logs/restaurant-flutter-client.log"
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

# ── 에이전트 시작 ───────────────────────────────────────────────────────────────
cd "$ROOT/samples/agent/adk/restaurant_finder"
uv sync --quiet 2>/dev/null || true
echo ">>> Starting Restaurant Agent (port 10002). Log: $DEMOS_ROOT/logs/restaurant-agent.log"
uv run . --port 10002 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-agent.log" &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 3

# ── Flutter 디바이스 감지 및 AGENT_URL 설정 ────────────────────────────────────
# DART_DEFINES 와 FLUTTER_DEVICE 를 설정한다.
#
# 실물 기기/에뮬레이터에서 앱이 에이전트에 접속하려면 localhost 대신
# 정확한 호스트 주소가 필요하다:
#   - 에뮬레이터     → 10.0.2.2 (Android 에뮬레이터의 호스트 alias)
#   - 실물 기기(USB) → 호스트 PC의 LAN IP (예: 192.168.1.10)
#   - Chrome (웹)    → localhost (그대로 사용)
#
# String.fromEnvironment 는 컴파일 타임 상수이므로 --dart-define 으로 주입한다.

_set_agent_url() {
  # $1: flutter devices 출력에서 추출한 기기 정보 라인
  local device_line="$1"
  local agent_host
  if echo "$device_line" | grep -qi "emulator"; then
    agent_host="10.0.2.2"
    echo ">>> 에뮬레이터 감지. 에이전트 URL: http://$agent_host:10002"
  else
    # adb reverse: 폰에서 localhost:PORT → PC의 PORT 로 포워딩 (Galaxy/실물 기기 권장).
    # adb reverse 성공 → localhost 사용 (가장 안정적).
    # 실패 시 → PC LAN IP로 폴백 (Wi-Fi 같은 네트워크 필요).
    if command -v adb &>/dev/null && \
       adb reverse tcp:10002 tcp:10002 2>/dev/null && \
       adb reverse tcp:10003 tcp:10003 2>/dev/null; then
      agent_host="localhost"
      echo ">>> [adb reverse] 포트 포워딩 성공 → 폰에서 localhost:10002 사용"
    else
      echo ">>> [adb reverse 실패] LAN IP로 폴백 (adb 미설치 또는 기기 미연결)"
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
  # restaurant(10002) 과 contacts(10003) 둘 다 설정
  DART_DEFINES="--dart-define=AGENT_URL=http://$agent_host:10002 --dart-define=CONTACTS_AGENT_URL=http://$agent_host:10003"
}

resolve_device() {
  DART_DEFINES=""
  local devices_output
  devices_output=$(flutter devices 2>/dev/null)

  if [[ -z "${FLUTTER_DEVICE:-}" ]]; then
    # FLUTTER_DEVICE 미지정: Android 기기가 연결돼 있으면 자동 사용,
    # 없으면 Chrome(웹) 으로 fallback
    local android_line
    android_line=$(echo "$devices_output" | grep -iE "android|mobile" | head -1)
    if [[ -n "$android_line" ]]; then
      local id
      id=$(echo "$android_line" | sed 's/ • /•/g' | awk -F'•' '{print $2}' | xargs)
      echo ">>> Android 기기 자동 감지: $android_line"
      echo ">>> 사용할 기기 ID: $id"
      FLUTTER_DEVICE="$id"
      _set_agent_url "$android_line"
    elif echo "$devices_output" | grep -q "Chrome"; then
      FLUTTER_DEVICE="chrome"
    else
      echo ">>> 실행 가능한 기기가 없습니다."
      echo "$devices_output"
      exit 1
    fi
    return
  fi

  local line
  if [[ "$FLUTTER_DEVICE" =~ ^[Aa]ndroid$ ]]; then
    # generic "android" → 연결된 첫 번째 Android 기기
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
    # 특정 기기 ID → flutter devices 에서 해당 기기 정보 조회
    line=$(echo "$devices_output" | grep "$FLUTTER_DEVICE" | head -1)
  fi
  _set_agent_url "$line"
}

# ── Flutter 클라이언트 실행 ─────────────────────────────────────────────────────
echo ">>> Starting Flutter Restaurant Shell. Log: $LOG"
cd "$FLUTTER_SHELL"
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
  # 웹: localhost 그대로 사용, debug 모드 OK
  flutter run -d chrome $DART_DEFINES 2>&1 | tee "$LOG"
else
  # 기기: release 모드로 실행 → setFrameRateCategory 로그 없음, 성능 대폭 개선
  echo ">>> 릴리즈 모드로 실행합니다 (debug 대비 성능 대폭 개선)."
  flutter run -d "$FLUTTER_DEVICE" --release $DART_DEFINES 2>&1 | tee "$LOG"
fi
