# A2UI Demo Scripts

프로젝트 루트가 아닌 **이 폴더(`demos/`)에서** 스크립트를 실행하면 됩니다.  
모든 데모는 **하나의 env 파일**(`.env`)에서 API 키와 모델을 읽고, LiteLLM 형식으로 맞춰서 사용합니다.

## 1. 환경 설정 (한 번만)

```bash
cd demos
cp .env.example .env
# .env를 열어서 아래를 설정:
#   OPENAI_API_KEY=sk-...        (Restaurant 등 OpenAI 사용 데모)
#   GEMINI_API_KEY=...           (Contact, Rizzcharts, Orchestrator 등)
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
| `./run-demo-contact-lit.sh` | Contact Lookup | Lit Shell | 10003, 5173 | GEMINI_API_KEY |
| `./run-demo-contact-angular.sh` | Contact Lookup | Angular (contact) | 10003 | GEMINI_API_KEY |
| `./run-demo-contact-multiple-lit.sh` | Contact Multiple Surfaces | Lit contact | 10004 | GEMINI_API_KEY |
| `./run-demo-rizzcharts-angular.sh` | Rizzcharts | Angular (rizzcharts) | 10002 | GEMINI_API_KEY |
| `./run-demo-orchestrator-angular.sh` | Orchestrator | Angular (orchestrator) | 10002 | GEMINI_API_KEY |
| `./run-demo-component-gallery-lit.sh` | Component Gallery | Lit component_gallery | 10005 | 없음 (LLM 없음) |

Lit Shell에서 Contact 데모는 브라우저에서 **http://localhost:5173/?app=contacts** 로 열면 됩니다.  
Contact/Contact Multiple 데모는 샘플 코드가 `GEMINI_API_KEY`를 요구합니다.

## 4. 요약

- **env**: `demos/.env` 한 곳에서 `GPT_MODEL`(또는 `LITELLM_MODEL`), `OPENAI_API_KEY`, `GEMINI_API_KEY` 설정.
- **실행**: `demos/`에서 `./run-demo-<이름>.sh` 실행.
- **동작 확인**: 에이전트 포트(10002 등) + 클라이언트 URL(5173, 5003 등)로 브라우저에서 확인.

이렇게 하면 수정 없이 제공된 샘플들을 그대로 돌려보며 A2UI 동작을 확인할 수 있습니다.
