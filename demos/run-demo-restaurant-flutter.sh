#!/usr/bin/env bash
# Restaurant Finder + Flutter (Lit-style: chat input + A2UI). Agent: 10002.
# Web: Chrome. Android: use FLUTTER_DEVICE=android or -d android when run separately.

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

resolve_flutter() {
  if command -v flutter &>/dev/null; then return; fi
  local dir
  for dir in "$FLUTTER_ROOT" "$FLUTTER_HOME" "$HOME/flutter" "$HOME/development/flutter" "$HOME/fvm/default" "/opt/flutter" "/usr/local/flutter"; do
    if [[ -n "$dir" && -x "$dir/bin/flutter" ]]; then
      export PATH="$dir/bin:$PATH"
      return
    fi
  done
}
resolve_flutter
if ! command -v flutter &>/dev/null; then
  echo "Flutter SDK is required. Install: https://docs.flutter.dev/get-started/install"
  echo "Or set FLUTTER_ROOT to your Flutter SDK path."
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
