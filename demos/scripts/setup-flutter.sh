#!/usr/bin/env bash
# Flutter SDK 설치 스크립트 (Linux x64 / macOS arm64·x64)
# 사용법: source demos/scripts/setup-flutter.sh
#         또는: bash demos/scripts/setup-flutter.sh   (설치만 하고 PATH 반영 안 됨)
#
# 환경 변수:
#   FLUTTER_ROOT      - 원하는 설치 경로 (기본: $HOME/flutter)
#   FLUTTER_VERSION   - 설치할 버전    (기본: 최신 stable)
#
# 학습 포인트:
#   - pub.dev 패키지(genui, genui_a2ui)가 Flutter SDK >= 3.35.7 을 요구한다.
#   - Linux: storage.googleapis.com 에서 tar.xz 다운로드 후 $HOME/flutter 에 설치.
#   - 설치 후 PATH 에 $FLUTTER_HOME/bin 을 추가해야 flutter 명령이 동작한다.

set -euo pipefail

# ── 상수 ──────────────────────────────────────────────────────────────────────
FLUTTER_REQUIRED_VERSION="3.35.7"   # pubspec.yaml flutter 최소 요구 버전
FLUTTER_INSTALL_DIR="${FLUTTER_ROOT:-$HOME/flutter}"

# ── 헬퍼 ──────────────────────────────────────────────────────────────────────
log()  { echo "[setup-flutter] $*"; }
warn() { echo "[setup-flutter] WARNING: $*" >&2; }
fail() { echo "[setup-flutter] ERROR: $*" >&2; exit 1; }

# 버전 비교: v1 >= v2 이면 0 반환
version_gte() {
  local v1=$1 v2=$2
  printf '%s\n%s\n' "$v2" "$v1" | sort -V -C
}

# ── 이미 Flutter 가 있는지 확인 ────────────────────────────────────────────────
resolve_existing_flutter() {
  # 1) PATH 에서 먼저 확인
  if command -v flutter &>/dev/null; then return 0; fi
  # 2) 일반 설치 경로들 순서대로 탐색
  local dir
  for dir in \
    "${FLUTTER_ROOT:-}" \
    "${FLUTTER_HOME:-}" \
    "$HOME/flutter" \
    "$HOME/development/flutter" \
    "$HOME/fvm/default" \
    "/opt/flutter" \
    "/usr/local/flutter"; do
    if [[ -n "$dir" && -x "$dir/bin/flutter" ]]; then
      export PATH="$dir/bin:$PATH"
      return 0
    fi
  done
  return 1
}

# ── 버전 검증 ──────────────────────────────────────────────────────────────────
check_flutter_version() {
  local current
  current=$(flutter --version --no-color 2>/dev/null | awk '/^Flutter / {print $2}') || true
  if [[ -z "$current" ]]; then
    warn "flutter --version 파싱 실패. 버전 체크를 건너뜁니다."
    return 0
  fi
  if version_gte "$current" "$FLUTTER_REQUIRED_VERSION"; then
    log "Flutter $current 확인 (>= $FLUTTER_REQUIRED_VERSION ✓)"
    return 0
  else
    warn "Flutter $current 은 너무 오래됐습니다 (필요: >= $FLUTTER_REQUIRED_VERSION)."
    return 1
  fi
}

# ── 최신 stable 버전 조회 ──────────────────────────────────────────────────────
latest_stable_version() {
  # Flutter 공식 releases API (storage.googleapis.com 는 허용 도메인)
  local releases_url="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
  local ver
  ver=$(curl -fsSL "$releases_url" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
channel = data.get('current_release', {}).get('stable', '')
for r in data.get('releases', []):
    if r.get('hash') == channel:
        print(r['version'].lstrip('v'))
        break
" 2>/dev/null) || true
  echo "${ver:-$FLUTTER_REQUIRED_VERSION}"
}

# ── Linux 설치 ─────────────────────────────────────────────────────────────────
install_flutter_linux() {
  local version="$1"
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)  arch="x64";;
    aarch64) arch="arm64";;
    *)       fail "지원하지 않는 아키텍처: $arch";;
  esac

  local filename="flutter_linux_${version}-stable.tar.xz"
  local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${filename}"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  log "Flutter $version 다운로드 중..."
  log "  URL : $url"
  log "  목적지: $FLUTTER_INSTALL_DIR"

  if ! curl -fL --progress-bar "$url" -o "$tmp_dir/$filename"; then
    fail "다운로드 실패. URL 확인: $url"
  fi

  log "압축 해제 중..."
  mkdir -p "$(dirname "$FLUTTER_INSTALL_DIR")"
  # flutter/ 디렉토리가 압축 안에 포함돼 있으므로 상위 디렉토리에 풀고 이동
  tar -xf "$tmp_dir/$filename" -C "$tmp_dir"
  if [[ -d "$FLUTTER_INSTALL_DIR" ]]; then
    rm -rf "$FLUTTER_INSTALL_DIR"
  fi
  mv "$tmp_dir/flutter" "$FLUTTER_INSTALL_DIR"

  export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
  log "Flutter $version 설치 완료: $FLUTTER_INSTALL_DIR"
}

# ── macOS 설치 ─────────────────────────────────────────────────────────────────
install_flutter_macos() {
  # brew 가 있으면 가장 간단
  if command -v brew &>/dev/null; then
    log "Homebrew 로 Flutter 설치 중..."
    brew install --cask flutter
    export PATH="$(brew --prefix)/bin:$PATH"
    return
  fi

  local version="$1"
  local arch
  arch=$(uname -m)
  local suffix
  case "$arch" in
    arm64)   suffix="arm64";;
    x86_64)  suffix="x64";;
    *)       fail "지원하지 않는 macOS 아키텍처: $arch";;
  esac

  local filename="flutter_macos_${suffix}_${version}-stable.zip"
  local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/${filename}"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  log "Flutter $version (macOS $suffix) 다운로드 중..."
  curl -fL --progress-bar "$url" -o "$tmp_dir/$filename" || fail "다운로드 실패"
  mkdir -p "$(dirname "$FLUTTER_INSTALL_DIR")"
  unzip -q "$tmp_dir/$filename" -d "$tmp_dir"
  [[ -d "$FLUTTER_INSTALL_DIR" ]] && rm -rf "$FLUTTER_INSTALL_DIR"
  mv "$tmp_dir/flutter" "$FLUTTER_INSTALL_DIR"
  export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
  log "Flutter $version 설치 완료: $FLUTTER_INSTALL_DIR"
}

# ── PATH 영구 등록 안내 ────────────────────────────────────────────────────────
print_path_hint() {
  local flutter_bin="$FLUTTER_INSTALL_DIR/bin"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Flutter PATH 영구 등록 (새 터미널에서도 동작하게)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ~/.bashrc 또는 ~/.zshrc 에 아래 줄 추가:"
  echo ""
  echo "    export PATH=\"$flutter_bin:\$PATH\""
  echo ""
  echo "  적용:"
  echo "    source ~/.bashrc   # bash"
  echo "    source ~/.zshrc    # zsh"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ── 메인 ──────────────────────────────────────────────────────────────────────
main() {
  # 이미 설치돼 있고 버전도 충분하면 바로 리턴
  if resolve_existing_flutter && check_flutter_version; then
    return 0
  fi

  log "Flutter SDK 가 없거나 버전이 낮습니다. 자동 설치를 시작합니다..."

  # 설치할 버전 결정
  local version="${FLUTTER_VERSION:-}"
  if [[ -z "$version" ]]; then
    log "최신 stable 버전 조회 중..."
    version=$(latest_stable_version)
    log "설치 대상 버전: $version"
  fi

  # 최소 요구 버전보다 낮으면 최소 버전으로 강제
  if ! version_gte "$version" "$FLUTTER_REQUIRED_VERSION"; then
    warn "조회된 버전($version) < 요구 버전($FLUTTER_REQUIRED_VERSION). 요구 버전으로 설치합니다."
    version="$FLUTTER_REQUIRED_VERSION"
  fi

  case "$(uname -s)" in
    Linux)  install_flutter_linux  "$version";;
    Darwin) install_flutter_macos  "$version";;
    *)      fail "지원하지 않는 OS: $(uname -s)";;
  esac

  # 설치 후 최종 확인
  if ! command -v flutter &>/dev/null; then
    fail "설치 후에도 flutter 명령을 찾을 수 없습니다."
  fi

  flutter --version --no-color 2>/dev/null | head -1 || true
  print_path_hint
}

main "$@"
