#!/usr/bin/env bash
# Restaurant Finder + Flutter (Lit-style: chat input + A2UI). Agent: 10002.
# Web: Chrome. Android: FLUTTER_DEVICE=<기기ID> 로 실행 (기기 ID는 'flutter devices' 참고).
#   예) FLUTTER_DEVICE=android   → 연결된 첫 번째 Android 기기 자동 감지
#   예) FLUTTER_DEVICE=RF8XN3J1H2T → 특정 기기 ID 직접 지정
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
    # generic "android" → 연결된 첫 번째 Android 기기 자동 감지
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

# Run Flutter client (web or Android via FLUTTER_DEVICE)
echo ">>> Starting Flutter Restaurant Shell. Log: $DEMOS_ROOT/logs/restaurant-flutter-client.log"
cd "$FLUTTER_SHELL"
flutter pub get
resolve_device
if [[ -n "${FLUTTER_DEVICE:-}" ]]; then
  flutter run -d "$FLUTTER_DEVICE" $DART_DEFINES 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-flutter-client.log"
elif flutter devices 2>/dev/null | grep -q "Chrome"; then
  flutter run -d chrome 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-flutter-client.log"
else
  echo "Available devices:"
  flutter devices
  flutter run $DART_DEFINES 2>&1 | tee "$DEMOS_ROOT/logs/restaurant-flutter-client.log"
fi
