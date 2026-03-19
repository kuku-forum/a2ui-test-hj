# A2UI Demo Scripts

프로젝트 루트가 아닌 **이 폴더(`demos/`)에서** 스크립트를 실행하면 됩니다.
모든 데모는 **하나의 env 파일**(`.env`)에서 API 키와 모델을 읽고, LiteLLM 형식으로 맞춰서 사용합니다.

---

## 1. 환경 설정 (한 번만)

```bash
cd demos
cp .env.example .env
# .env 를 열어서 아래 중 하나를 설정하세요
```

**공개 OpenAI 사용:**
```env
OPENAI_API_KEY=sk-...
GPT_MODEL=gpt-4o          # LITELLM_MODEL=openai/gpt-4o 로 자동 변환
```

**사내 AI proxy (OpenAI 호환 엔드포인트) 사용:**
```env
OPENAI_API_KEY=<회사 발급 키>
OPENAI_API_BASE=https://your-company-ai-gateway.example.com/v1
LITELLM_MODEL=openai/gpt-4.1
```

> `LITELLM_MODEL` 을 직접 지정하면 `GPT_MODEL` / `GEMINI_MODEL` 자동 변환보다 우선합니다.

---

## 2. 빌드 (최초 1회 또는 의존성 변경 시)

```bash
./scripts/build-all.sh
```

- renderers: web_core, markdown-it, lit, react
- 클라이언트: Lit shell, React shell

Angular 데모는 `npm run start` 시 자동 빌드됩니다.

---

## 3. 데모 실행 (에이전트 + 클라이언트 한 번에)

아래 스크립트는 **에이전트를 백그라운드로 띄운 뒤** 해당 클라이언트를 실행합니다.
Ctrl+C 로 종료하면 에이전트 프로세스도 함께 정리됩니다.

| 스크립트 | 에이전트 | 클라이언트 | 포트 | 필요 키 |
|----------|----------|------------|------|---------|
| `./run-demo-restaurant-lit.sh` | Restaurant Finder | Lit Shell | 10002, 5173 | OPENAI |
| `./run-demo-restaurant-react.sh` | Restaurant Finder | React Shell | 10002, 5003 | OPENAI |
| `./run-demo-restaurant-angular.sh` | Restaurant Finder | Angular | 10002 | OPENAI |
| `./run-demo-restaurant-flutter.sh` | Restaurant Finder | **Flutter** (웹/Android) | 10002 | OPENAI, Flutter SDK |
| `./run-demo-contact-lit.sh` | Contact Lookup | Lit Shell | 10003, 5173 | OPENAI 또는 GEMINI |
| `./run-demo-contact-angular.sh` | Contact Lookup | Angular | 10003 | OPENAI 또는 GEMINI |
| `./run-demo-contact-multiple-lit.sh` | Contact (Multi Surface) | Lit | 10004 | OPENAI 또는 GEMINI |
| `./run-demo-rizzcharts-angular.sh` | Rizzcharts | Angular | 10002 | OPENAI 또는 GEMINI |
| `./run-demo-orchestrator-angular.sh` | Orchestrator | Angular | 10002 | OPENAI 또는 GEMINI |
| `./run-demo-component-gallery-lit.sh` | Component Gallery | Lit | 10005 | 없음 |

**Lit Shell** (`http://localhost:5173`): 기본으로 Restaurant 앱이 뜹니다. Contact 는 상단 Contacts 버튼 또는 `?app=contacts` URL 파라미터.

---

## 4. Flutter 데모 (restaurant-flutter)

Lit/React/Angular 와 동일한 채팅+A2UI 화면을 Flutter 로 구현한 데모입니다.
PC에 USB로 연결된 실물 Android 기기 또는 Chrome(웹)에서 동작합니다.

### 사전 준비

- Flutter SDK: 없으면 스크립트 실행 시 자동 설치됨
- Android 기기 사용 시: **USB 디버깅 활성화** + PC에 USB 연결

### 방법 1 — 원 커맨드 (에이전트 + 클라이언트 한 번에)

```bash
cd demos

# [웹 Chrome] 기기 없어도 바로 실행 가능
./run-demo.sh restaurant-flutter

# [Android 기기] USB 연결 후 → 첫 번째 연결 기기 자동 감지
FLUTTER_DEVICE=android ./run-demo.sh restaurant-flutter

# [Android 기기] flutter devices 로 기기 ID 확인 후 직접 지정
FLUTTER_DEVICE=RF8XN3J1H2T ./run-demo.sh restaurant-flutter
```

> `FLUTTER_DEVICE` 를 지정하지 않아도 Android 기기가 연결되어 있으면 자동 감지합니다.

### 방법 2 — 터미널 두 개 (에이전트/클라이언트 로그 분리)

```bash
# 터미널 1 — 에이전트 먼저 실행
cd demos
./scripts/run-agent-restaurant.sh

# 터미널 2 — Flutter 클라이언트 (에이전트 실행 후)
cd demos
./scripts/run-client-flutter-shell.sh                     # Chrome 또는 Android 자동 감지

# Android 기기 지정 시:
FLUTTER_DEVICE=android ./scripts/run-client-flutter-shell.sh
FLUTTER_DEVICE=RF8XN3J1H2T ./scripts/run-client-flutter-shell.sh
```

### 연결 방식별 AGENT_URL 자동 처리

스크립트가 기기 종류에 따라 `AGENT_URL` 을 자동으로 설정합니다 (직접 설정 불필요).

| 실행 대상 | AGENT_URL | 비고 |
|-----------|-----------|------|
| Chrome (웹) | `http://localhost:10002` | 기본값 |
| Android 에뮬레이터 | `http://10.0.2.2:10002` | 에뮬레이터 → 호스트 alias |
| **실물 Android 기기** | `http://<호스트 LAN IP>:10002` | **자동 감지** |

> 실물 기기 연결 시 PC 방화벽에서 포트 10002 를 허용해야 합니다.

### 자주 묻는 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| `connection refused … localhost:10002` | AGENT_URL 이 localhost 로 설정됨 | 위 "자동 처리" 참고; 기기 연결 확인 |
| 앱이 매우 느림 | debug 모드로 실행됨 | 스크립트가 기기 실행 시 `--release` 모드 자동 적용 |
| `no device matching 'android'` | 구버전 스크립트 사용 | `git pull` 후 재시도 |
| Flutter SDK 없음 | SDK 미설치 | 스크립트 실행 시 자동 설치 (`~/flutter`) |

---

## 5. 터미널 두 개로 서버/클라이언트 나눠 실행

에이전트 로그와 클라이언트 로그를 분리해서 보고 싶을 때 사용합니다.

**터미널 1 — 에이전트만**
```bash
cd demos
./scripts/run-agent-restaurant.sh
# → A2A 메시지, surface 업데이트 등 에이전트 로그만 출력
```

**터미널 2 — 클라이언트만** (에이전트가 10002 포트에서 실행 중이어야 함)
```bash
cd demos

# Lit Shell (웹)
./scripts/run-client-lit.sh          # http://localhost:5173

# Flutter (웹 Chrome 또는 Android 자동 감지)
./scripts/run-client-flutter-shell.sh

# Flutter (Android 기기 지정)
FLUTTER_DEVICE=android ./scripts/run-client-flutter-shell.sh
```

---

## 6. 로그 확인

에이전트·클라이언트 출력은 `demos/logs/` 에도 기록됩니다.

```bash
tail -f demos/logs/restaurant-agent.log
tail -f demos/logs/restaurant-flutter-client.log
```

---

## 7. 요약

| 항목 | 내용 |
|------|------|
| **환경 설정** | `demos/.env` 에 `OPENAI_API_KEY` + (`GPT_MODEL` 또는 `LITELLM_MODEL`) |
| **사내 proxy** | `OPENAI_API_BASE` + `LITELLM_MODEL=openai/<모델>` 추가 |
| **한 터미널** | `./run-demo-<이름>.sh` 또는 `./run-demo.sh <이름>` |
| **두 터미널** | `./scripts/run-agent-*.sh` (터미널 1) + `./scripts/run-client-*.sh` (터미널 2) |
| **Flutter Android** | `FLUTTER_DEVICE=android` 환경 변수 설정 (또는 생략 시 자동 감지) |
| **로그** | `demos/logs/*.log` |
