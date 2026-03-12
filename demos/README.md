# A2UI Demo Scripts

프로젝트 루트가 아닌 **이 폴더(`demos/`)에서** 스크립트를 실행하면 됩니다.  
모든 데모는 **하나의 env 파일**(`.env`)에서 API 키와 모델을 읽고, LiteLLM 형식으로 맞춰서 사용합니다.

## 1. 환경 설정 (한 번만)

```bash
cd demos
cp .env.example .env
# .env를 열어서 아래를 설정:
#   OPENAI_API_KEY=sk-...        (모든 데모에서 사용 가능; 이것만 있으면 됨)
#   GEMINI_API_KEY=...           (선택, Contact/Rizzcharts/Orchestrator를 Gemini 모델로 쓸 때)
#   GPT_MODEL=gpt-5.4            (예: gpt-5.4, gpt-4o → LITELLM_MODEL=openai/gpt-5.4 로 자동 매핑)
#   GEMINI_MODEL=gemini-2.5-flash (선택, Gemini 데모용)
```

- **GPT 버전만 넣고 싶을 때**: `GPT_MODEL=gpt-5.4` 만 넣으면 스크립트가 `LITELLM_MODEL=openai/gpt-5.4` 로 설정합니다.
- **LiteLLM 값을 직접 쓰고 싶을 때**: `.env`에 `LITELLM_MODEL=openai/gpt-5.4` 처럼 넣으면 그대로 사용됩니다.

## 2. 빌드 (최초 1회 또는 의존성 변경 시)

```bash
./scripts/build-all.sh
```

- renderers: web_core, markdown-it, lit, react  
- 클라이언트: Lit shell, React shell  

Angular 데모는 `npm run start` 시 빌드됩니다.

## 3. 데모 실행

아래 스크립트는 **에이전트를 백그라운드로 띄운 뒤** 해당 클라이언트를 실행합니다.  
종료 시 에이전트 프로세스도 함께 정리됩니다.

| 스크립트 | 에이전트 | 클라이언트 | 포트 | 필요 키 |
|----------|----------|------------|------|---------|
| `./run-demo-restaurant-lit.sh` | Restaurant Finder | Lit Shell | 10002, 5173 | OPENAI_API_KEY |
| `./run-demo-restaurant-react.sh` | Restaurant Finder | React Shell | 10002, 5003 | OPENAI_API_KEY |
| `./run-demo-restaurant-angular.sh` | Restaurant Finder | Angular (restaurant) | 10002 | OPENAI_API_KEY |
| `./run-demo-restaurant-flutter.sh` | Restaurant Finder | **Flutter** (채팅+A2UI, 웹/Android) | 10002 | OPENAI_API_KEY, Flutter SDK |
| `./run-demo-contact-lit.sh` | Contact Lookup | Lit Shell | 10003, 5173 | OPENAI 또는 GEMINI |
| `./run-demo-contact-angular.sh` | Contact Lookup | Angular (contact) | 10003 | OPENAI 또는 GEMINI |
| `./run-demo-contact-multiple-lit.sh` | Contact Multiple Surfaces | Lit contact | 10004 | OPENAI 또는 GEMINI |
| `./run-demo-rizzcharts-angular.sh` | Rizzcharts | Angular (rizzcharts) | 10002 | OPENAI 또는 GEMINI |
| `./run-demo-orchestrator-angular.sh` | Orchestrator | Angular (orchestrator) | 10002 | OPENAI 또는 GEMINI |
| `./run-demo-component-gallery-lit.sh` | Component Gallery | Lit component_gallery | 10005 | 없음 (LLM 없음) |

**모든 데모는 OPENAI_API_KEY만으로 실행 가능합니다.** Contact / Rizzcharts / Orchestrator는 GEMINI_API_KEY를 설정하면 Gemini 모델을 사용할 수 있습니다.

**Lit Shell**: `http://localhost:5173` 만 열면 기본으로 **Restaurant** 앱이 뜹니다. Contact를 쓰려면 페이지 상단의 **Contacts** 버튼을 누르거나 `http://localhost:5173/?app=contacts` 로 들어가면 됩니다.

**Flutter 데모** (`./run-demo.sh restaurant-flutter`): Lit과 동일하게 채팅 입력 + A2UI 결과. 웹(Chrome) 또는 Android에서 실행.
- **웹**: 기본으로 Chrome에서 실행. 입력창에 포커스되어 바로 입력 가능.
- **Android**: 에뮬레이터/기기에서 실행하려면 `FLUTTER_DEVICE=android ./run-demo.sh restaurant-flutter` 또는, 터미널 두 개로 나눠 실행할 때 터미널 2에서 `FLUTTER_DEVICE=android ./scripts/run-client-flutter-shell.sh`. Android 에뮬레이터에서 에이전트에 접속하려면 에이전트를 호스트에서 띄운 뒤, 앱에서 접속 주소가 `localhost:10002`이면 에뮬레이터는 호스트를 `10.0.2.2`로 접근하므로 `flutter run -d android --dart-define=AGENT_URL=http://10.0.2.2:10002` 처럼 실행할 수 있음.

## 4. 로그 폴더

에이전트·클라이언트 출력은 **`demos/logs/`** 에도 기록됩니다. 터미널 로그를 나중에 보고 싶을 때:

```bash
tail -f demos/logs/restaurant-agent.log
tail -f demos/logs/restaurant-flutter-client.log
```

자세한 내용은 `demos/logs/README.md` 참고.

## 5. 터미널 두 개로 서버/클라이언트 나눠 실행 (로그 따로 보기)

에이전트 로그와 클라이언트 로그를 각각 보고 싶을 때는 **demos** 폴더에서 아래처럼 두 터미널로 나눠 실행하면 됩니다.

**터미널 1 – 서버(에이전트)만**
```bash
cd demos
./scripts/run-agent-restaurant.sh
```
→ 이 터미널에만 에이전트 로그가 출력됩니다 (A2A 메시지, surface 업데이트 등).

**터미널 2 – 클라이언트만** (에이전트가 10002에서 떠 있는 상태에서)
```bash
cd demos
./scripts/run-client-lit.sh
```
→ Lit Shell (http://localhost:5173). 빌드/번들 로그는 이 터미널에 나옵니다.

Flutter 클라이언트만 띄우려면 (웹 기본, Android는 `FLUTTER_DEVICE=android`):
```bash
cd demos
./scripts/run-client-flutter-shell.sh
```

정리: **1번 터미널**에서 `./scripts/run-agent-restaurant.sh` 먼저 실행하고, **2번 터미널**에서 `./scripts/run-client-lit.sh` 또는 `./scripts/run-client-flutter-shell.sh` 실행하면 됩니다.

## 6. 요약

- **env**: `demos/.env` 한 곳에서 `GPT_MODEL`(또는 `LITELLM_MODEL`), `OPENAI_API_KEY` 설정. (모든 데모는 OPENAI만으로 동작; `GEMINI_API_KEY`는 선택.)
- **실행**: `demos/`에서 `./run-demo-<이름>.sh` 실행 (한 터미널에 에이전트+클라이언트).
- **서버/클라이언트 분리**: `./scripts/run-agent-restaurant.sh` (터미널 1) + `./scripts/run-client-lit.sh` 또는 `./scripts/run-client-flutter-shell.sh` (터미널 2).
- **로그**: `demos/logs/*.log` 에 에이전트/클라이언트 출력이 기록됨.
- **동작 확인**: 에이전트 포트(10002 등) + 클라이언트 URL(5173, 5003 등)로 브라우저에서 확인.

이렇게 하면 수정 없이 제공된 샘플들을 그대로 돌려보며 A2UI 동작을 확인할 수 있습니다.

## 7. 검증 (2025-03-12)

다음이 적용된 상태에서 데모 스크립트 동작을 확인했습니다.

- **실행 권한**: `run-demo-*.sh`, `scripts/*.sh` 실행 가능
- **클라이언트 의존성**: Node 클라이언트 데모에서 `npm install` 후 `npm run dev`/`npm run start` 실행
- **포트 충돌**: 에이전트 기동 전 해당 포트 사용 여부 확인, 사용 중이면 안내 메시지 후 종료
- **OpenAI 단일 키**: 모든 데모가 `OPENAI_API_KEY`만으로 실행 가능 (Contact/Rizzcharts/Orchestrator는 `GEMINI_API_KEY` 선택)

전체 데모를 한 번씩 실행하려면 `demos/.env`에 `OPENAI_API_KEY`를 설정한 뒤, 각 데모마다 `./run-demo.sh <이름>`으로 실행해 보면 됩니다. Flutter 데모는 Flutter SDK가 필요합니다.
