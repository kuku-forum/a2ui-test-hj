# A2UI 데모 아키텍처 완전 가이드
## Lit & Flutter 데모 — 서버·클라이언트 연결 구조 총정리

> **이 문서 하나만 읽으면 A2UI 전체 흐름을 이해할 수 있도록 작성되었습니다.**
> Restaurant Finder 데모를 기준으로, Lit(웹)과 Flutter(모바일/웹) 클라이언트가
> 서버 에이전트와 어떻게 통신하는지 코드 레벨까지 설명합니다.

---

## 목차

1. [A2UI란?](#1-a2ui란)
2. [전체 시스템 아키텍처](#2-전체-시스템-아키텍처)
3. [메시지 프로토콜 상세](#3-메시지-프로토콜-상세)
4. [서버(에이전트) 내부 구조](#4-서버에이전트-내부-구조)
5. [Lit 클라이언트 아키텍처](#5-lit-클라이언트-아키텍처)
6. [Flutter 클라이언트 아키텍처](#6-flutter-클라이언트-아키텍처)
7. [서버 ↔ 클라이언트 실제 통신 흐름](#7-서버--클라이언트-실제-통신-흐름)
8. [컴포넌트 연결 맵](#8-컴포넌트-연결-맵)
9. [코드 레퍼런스 색인](#9-코드-레퍼런스-색인)

---

## 1. A2UI란?

**A2UI (Agent to UI)** 는 AI 에이전트가 생성한 JSON 메시지를
클라이언트가 **네이티브 UI 컴포넌트**로 렌더링하는 오픈 프로토콜입니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                    A2UI가 해결하는 문제                           │
│                                                                  │
│  기존 방식 (텍스트):                                              │
│    User  → "뉴욕 중식당 예약해줘"                                │
│    Agent → "날짜를 알려주세요"                                    │
│    User  → "내일"                                                │
│    Agent → "몇 명인가요?"  ← 비효율적!                           │
│                                                                  │
│  A2UI 방식:                                                      │
│    User  → "뉴욕 중식당 예약해줘"                                │
│    Agent → 예약 폼(날짜선택+인원+시간) JSON 전송                 │
│    User  → 폼을 채우고 [예약하기] 클릭 ← 한 번에 완료!          │
└─────────────────────────────────────────────────────────────────┘
```

### A2UI의 3대 원칙

| 원칙 | 내용 | 왜 중요한가 |
|------|------|-------------|
| **보안** | 선언형 JSON(코드 아님) | 에이전트가 임의 코드를 실행할 수 없음 |
| **네이티브 느낌** | iframe 없음, 클라이언트 컴포넌트 사용 | 앱 스타일 그대로 유지 |
| **이식성** | 동일 JSON → 웹·모바일·데스크톱 렌더링 | 에이전트 하나로 모든 플랫폼 지원 |

---

## 2. 전체 시스템 아키텍처

```
╔══════════════════════════════════════════════════════════════════════╗
║                    RESTAURANT FINDER DEMO 전체 구조                  ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ┌─────────────────────────────────────────────────────────────┐    ║
║  │                    SERVER SIDE  (Python)                    │    ║
║  │                  localhost:10002                            │    ║
║  │                                                             │    ║
║  │  ┌──────────────┐    ┌─────────────────┐    ┌───────────────┐ │    ║
║  │  │  __main__.py │───▶│ RestaurantAgent │───▶│  OpenAI       │ │    ║
║  │  │  (A2A Server)│    │   Executor      │    │  GPT-4o-mini  │ │    ║
║  │  └──────────────┘    └─────────────────┘    │ (LITELLM_MODEL│ │    ║
║  │                                              │  env 로 변경) │ │    ║
║  │                                              └───────────────┘ │    ║
║  │         │                    │                              │    ║
║  │         │            ┌───────┴────────┐                    │    ║
║  │         │            │ RestaurantAgent │                    │    ║
║  │         │            │  (ui / text)   │                    │    ║
║  │         │            └───────┬────────┘                    │    ║
║  │         │                    │                              │    ║
║  │         │            ┌───────┴──────┐  ┌───────────────┐  │    ║
║  │         │            │ A2uiSchema   │  │ get_restaurants│  │    ║
║  │         │            │  Manager     │  │   (Tool)       │  │    ║
║  │         │            └──────────────┘  └───────────────┘  │    ║
║  └─────────────────────────────────────────────────────────────┘    ║
║           │                                                          ║
║           │  A2A Protocol (HTTP POST)                               ║
║           │  Header: X-A2A-Extensions: a2ui/v0.8                   ║
║           ▼                                                          ║
║  ┌─────────────────────────────────────────────────────────────┐    ║
║  │              CLIENT SIDE                                    │    ║
║  │                                                             │    ║
║  │  [Lit Shell]                  [Flutter Shell]               │    ║
║  │  samples/client/lit/shell     samples/client/flutter/       │    ║
║  │  localhost:5173               restaurant_shell              │    ║
║  │                                                             │    ║
║  │  ┌─────────────┐             ┌──────────────────────┐      │    ║
║  │  │ a2ui-shell  │             │  RestaurantShellApp  │      │    ║
║  │  │  (LitElement│             │  (Flutter Widget)    │      │    ║
║  │  │   Web Comp.)│             └──────────────────────┘      │    ║
║  │  └─────────────┘                                            │    ║
║  └─────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 데모 실행 구조

```
데모 시작
    │
    ├─ run-demo-restaurant-lit.sh
    │       │
    │       ├─ [1] uv run . --port 10002   → RestaurantAgent (Python)
    │       └─ [2] npm run dev             → Lit Shell (Vite, :5173)
    │
    └─ run-demo-restaurant-flutter.sh
            │
            ├─ [1] uv run . --port 10002   → RestaurantAgent (Python)
            └─ [2] flutter run -d chrome   → Flutter Web (:8080)
                   flutter run -d <device> → Flutter Android
```

---

## 3. 메시지 프로토콜 상세

### 3.1 A2UI 메시지 타입 (v0.8 Stable)

```
┌─────────────────────────────────────────────────────────────┐
│                   서버 → 클라이언트 메시지                    │
├────────────────────┬────────────────────────────────────────┤
│ 메시지 타입        │ 역할                                    │
├────────────────────┼────────────────────────────────────────┤
│ surfaceUpdate      │ UI 컴포넌트 정의/업데이트               │
│ dataModelUpdate    │ 데이터 상태 업데이트                    │
│ beginRendering     │ 렌더링 시작 신호 (root 컴포넌트 지정)  │
│ deleteSurface      │ Surface 제거                           │
└────────────────────┴────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   클라이언트 → 서버 메시지                    │
├────────────────────┬────────────────────────────────────────┤
│ 메시지 타입        │ 역할                                    │
├────────────────────┼────────────────────────────────────────┤
│ userAction         │ 버튼 클릭, 폼 제출 등 UI 이벤트        │
│ text (TextPart)    │ 일반 텍스트 메시지                     │
└────────────────────┴────────────────────────────────────────┘
```

### 3.2 레스토랑 예약 메시지 전체 흐름 예시

```
사용자: "뉴욕 중식당 Top 5 보여줘"
              │
              ▼
[서버가 보내는 메시지 시퀀스]

① surfaceUpdate ──────────────────────────────────────────────
{
  "surfaceUpdate": {
    "surfaceId": "default",
    "components": [
      { "id": "root", "component": { "Column": { "children": {
          "explicitList": ["title", "restaurant-list"] }}}},
      { "id": "title", "component": {
          "Text": { "text": { "literalString": "Top 5 Chinese in NY" }}}},
      { "id": "restaurant-list", "component": {
          "List": { "children": { "dynamicList": {
              "itemsPath": "/restaurants",
              "itemTemplate": "restaurant-card" }}}}},
      { "id": "restaurant-card", "component": {
          "Card": { ... }}},
      { "id": "book-btn", "component": {
          "Button": {
            "child": "book-text",
            "action": {
              "name": "book_restaurant",
              "context": [
                { "key": "restaurantName", "value": { "path": "/restaurants[i]/name" }},
                { "key": "address", "value": { "path": "/restaurants[i]/address" }}
              ]
            }
          }
      }}
    ]
  }
}

② dataModelUpdate ────────────────────────────────────────────
{
  "dataModelUpdate": {
    "surfaceId": "default",
    "contents": [
      { "key": "restaurants", "valueList": [ ...레스토랑 데이터... ] }
    ]
  }
}

③ beginRendering ─────────────────────────────────────────────
{
  "beginRendering": {
    "surfaceId": "default",
    "root": "root"
  }
}
              │
              ▼
[클라이언트 렌더링 완료]

사용자가 [예약하기] 클릭
              │
              ▼
[클라이언트 → 서버]
{
  "userAction": {
    "name": "book_restaurant",
    "surfaceId": "default",
    "sourceComponentId": "book-btn",
    "timestamp": "2026-03-19T10:30:00Z",
    "context": {
      "restaurantName": "Jing Fong",
      "address": "20 Elizabeth St, New York"
    }
  }
}
```

### 3.3 Surface와 Component 개념

```
┌─────────────────────────────────────────────────────────────┐
│                      Surface 구조                            │
│                                                              │
│  Surface (surfaceId: "default")                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Component Registry (Adjacency List)                 │   │
│  │                                                      │   │
│  │  "root"          → Column                            │   │
│  │    ├── "title"   → Text  ("Top 5 Chinese...")        │   │
│  │    └── "list"    → List                              │   │
│  │          └── [dynamicList: /restaurants]             │   │
│  │                ├── Card (restaurants[0])             │   │
│  │                │    ├── Image, Text, Button...       │   │
│  │                ├── Card (restaurants[1])             │   │
│  │                └── ...                               │   │
│  │                                                      │   │
│  │  Data Model (JSON Pointer 바인딩)                    │   │
│  │  /restaurants → [{ name, address, imageUrl, ... }]   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

> **왜 Adjacency List(인접 리스트)?**
> 중첩 트리 대신 flat한 ID 참조 구조를 쓰면 LLM이 순서에 관계없이
> 컴포넌트를 생성·수정할 수 있어 스트리밍에 최적화됩니다.

---

## 4. 서버(에이전트) 내부 구조

```
╔═══════════════════════════════════════════════════════════════╗
║              samples/agent/adk/restaurant_finder/             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  __main__.py                                                  ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ main()                                                 │  ║
║  │   ├─ RestaurantAgent(use_ui=True)  → ui_agent          │  ║
║  │   ├─ RestaurantAgent(use_ui=False) → text_agent        │  ║
║  │   ├─ RestaurantAgentExecutor(ui_agent, text_agent)     │  ║
║  │   ├─ DefaultRequestHandler(executor, InMemoryTaskStore)│  ║
║  │   ├─ A2AStarletteApplication(agent_card, handler)      │  ║
║  │   ├─ CORSMiddleware (localhost:* 허용)                  │  ║
║  │   ├─ StaticFiles(/static → images/)                    │  ║
║  │   └─ /debug, /debug/stream (SSE 로그 뷰어)             │  ║
║  └────────────────────────────────────────────────────────┘  ║
║           │                                                   ║
║           ▼                                                   ║
║  RestaurantAgentExecutor  (agent_executor.py)                 ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ execute(context, event_queue)                          │  ║
║  │   ├─ [1] try_activate_a2ui_extension(context)         │  ║
║  │   │       → X-A2A-Extensions 헤더 확인                │  ║
║  │   │       → use_ui = True/False 결정                  │  ║
║  │   │                                                    │  ║
║  │   ├─ [2] 메시지 파트 파싱                              │  ║
║  │   │   ├─ DataPart.userAction  → UI 이벤트             │  ║
║  │   │   └─ TextPart             → 텍스트 쿼리            │  ║
║  │   │                                                    │  ║
║  │   ├─ [3] action 처리                                   │  ║
║  │   │   ├─ "book_restaurant" → 예약 폼 요청             │  ║
║  │   │   ├─ "submit_booking"  → 예약 확정                │  ║
║  │   │   └─ else              → context.get_user_input()  │  ║
║  │   │                                                    │  ║
║  │   ├─ [4] agent.stream(query, session_id)              │  ║
║  │   │   └─ TaskState: working → input_required/completed│  ║
║  │   │                                                    │  ║
║  │   └─ [5] Flutter 호환 처리                            │  ║
║  │       ├─ book_ctx 주입 (restaurantName/address/image) │  ║
║  │       ├─ dietary 필드 제거 (Flutter IME 버그 회피)    │  ║
║  │       └─ surfaceId 리매핑 → "default"                 │  ║
║  └────────────────────────────────────────────────────────┘  ║
║           │                                                   ║
║           ▼                                                   ║
║  RestaurantAgent  (agent.py)                                  ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ __init__(base_url, use_ui)                             │  ║
║  │   ├─ A2uiSchemaManager(VERSION_0_8, BasicCatalog)     │  ║
║  │   ├─ LlmAgent(LiteLlm("openai/gpt-4o-mini"))         │  ║
║  │   └─ Runner(                                          │  ║
║  │        artifact_service=InMemoryArtifactService(),   │  ║
║  │        session_service=InMemorySessionService(),      │  ║
║  │        memory_service=InMemoryMemoryService())        │  ║
║  │                                                        │  ║
║  │ stream(query, session_id)                              │  ║
║  │   ├─ [1] session 생성/조회                             │  ║
║  │   ├─ [2] runner.run_async() → LLM 호출               │  ║
║  │   │       └─ get_restaurants(cuisine, location) Tool  │  ║
║  │   ├─ [3] parse_response() → A2UI JSON 추출            │  ║
║  │   ├─ [4] schema validator 검증                        │  ║
║  │   ├─ [5] 실패 시 최대 1회 재시도                       │  ║
║  │   └─ [6] parse_response_to_parts() → Part[] 반환      │  ║
║  └────────────────────────────────────────────────────────┘  ║
╚═══════════════════════════════════════════════════════════════╝
```

### 4.1 A2UI 확장(Extension) 협상 과정

```
클라이언트                              서버
    │                                    │
    │─── GET /.well-known/agent-card.json ──▶│
    │                                    │
    │◀── AgentCard {                     │
    │      capabilities: {               │
    │        extensions: [{              │
    │          uri: "a2ui.org/.../v0.8" │
    │        }]                          │
    │      }                             │
    │    }                              ──│
    │                                    │
    │─── POST /                         ─▶│
    │    Header: X-A2A-Extensions:       │
    │      "https://a2ui.org/a2a-        │
    │       extension/a2ui/v0.8"         │
    │                                    │
    │                     try_activate_a2ui_extension()
    │                     → use_ui = True
    │                     → UI JSON 응답 생성
    │                                    │
    │◀─── DataPart (A2UI JSON) ──────────│
```

### 4.2 Python SDK 핵심 구성요소

```
agent_sdks/python/src/a2ui/

├── a2a.py                    ← A2A 프로토콜 연동 핵심
│   ├── create_a2ui_part()        DataPart 생성
│   ├── get_a2ui_agent_extension() AgentCard extension 설정
│   ├── parse_response_to_parts() LLM 응답 → Part[] 변환
│   └── try_activate_a2ui_extension() 확장 활성화 확인
│
├── core/
│   ├── schema/
│   │   ├── manager.py         A2uiSchemaManager
│   │   │                       (스키마 로드, 시스템 프롬프트 생성)
│   │   ├── validator.py       JSON Schema 검증
│   │   └── catalog.py         컴포넌트 카탈로그 관리
│   └── parser/
│       └── parser.py          parse_response()
│                               (<a2ui>...</a2ui> 태그 파싱)
│
└── basic_catalog/
    └── provider.py            BasicCatalog
                                (기본 제공 컴포넌트 목록)
```

---

## 5. Lit 클라이언트 아키텍처

```
╔═══════════════════════════════════════════════════════════════╗
║          samples/client/lit/shell/  (Vite + Lit + TypeScript) ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  index.html                                                   ║
║  └── <a2ui-shell> (Web Component)                             ║
║          │                                                    ║
║          ▼                                                    ║
║  app.ts — A2UILayoutEditor extends SignalWatcher(LitElement)  ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │                                                        │  ║
║  │  @provide theme        → Lit Context (전역 테마)       │  ║
║  │  @provide markdownRenderer → 마크다운 렌더러           │  ║
║  │                                                        │  ║
║  │  #processor = createSignalA2uiMessageProcessor()       │  ║
║  │     └── Signal 기반 반응형 상태 관리                   │  ║
║  │                                                        │  ║
║  │  #a2uiClient = new A2UIClient()   // ① 필드 초기화    │  ║
║  │  // connectedCallback()에서 재초기화:                 │  ║
║  │  // #a2uiClient = new A2UIClient(config.serverUrl)   │  ║
║  │     └── A2A 프로토콜 HTTP 클라이언트                   │  ║
║  │                                                        │  ║
║  │  render()                                              │  ║
║  │   ├─ #renderThemeToggle()   다크/라이트 모드 토글      │  ║
║  │   ├─ #maybeRenderForm()     초기 입력 폼 (응답 전)     │  ║
║  │   ├─ #maybeRenderData()     Surface 렌더링 (응답 후)   │  ║
║  │   └─ #maybeRenderError()    에러 표시                  │  ║
║  │                                                        │  ║
║  │  #maybeRenderData() 핵심:                              │  ║
║  │   └── repeat(processor.getSurfaces(), ...)             │  ║
║  │         └── <a2ui-surface>                             │  ║
║  │               @a2uiaction → #sendAndProcessMessage()   │  ║
║  │                                                        │  ║
║  │  #sendAndProcessMessage(request)                       │  ║
║  │   ├─ await #sendMessage(request)   → 서버 호출         │  ║
║  │   ├─ processor.clearSurfaces()                         │  ║
║  │   └─ processor.processMessages(messages)               │  ║
║  │                                                        │  ║
║  └────────────────────────────────────────────────────────┘  ║
║                                                               ║
║  client.ts — A2UIClient                                       ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ send(message)                                          │  ║
║  │   ├─ A2AClient.fromCardUrl(/.well-known/agent-card)    │  ║
║  │   ├─ Header: X-A2A-Extensions: a2ui/v0.8 추가         │  ║
║  │   ├─ sendMessage({ parts: [DataPart | TextPart] })     │  ║
║  │   └─ result.status.message.parts → ServerToClientMsg[] │  ║
║  └────────────────────────────────────────────────────────┘  ║
║                                                               ║
║  middleware/a2a.ts — Vite Plugin (프록시)                     ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ POST /a2a → 에이전트 서버 프록시                       │  ║
║  │   (개발 환경에서 CORS 우회용으로 사용)                  │  ║
║  └────────────────────────────────────────────────────────┘  ║
╚═══════════════════════════════════════════════════════════════╝
```

### 5.1 Lit 렌더러 컴포넌트 계층

```
renderers/lit/src/0.8/

┌─ ui/ui.ts  ─────────── 컴포넌트 레지스트리 (전체 맵)
│
├─ ui/surface.ts ──────── <a2ui-surface>
│    Surface 전체를 관리하는 최상위 컨테이너
│    processor.getSurfaces() 에서 데이터를 받아 자식 렌더링
│
├─ ui/root.ts ─────────── <a2ui-root>
│    beginRendering의 root 컴포넌트
│
├─ [레이아웃 컴포넌트]
│   ├─ ui/column.ts ───── <a2ui-column>  세로 배치
│   ├─ ui/row.ts ─────── <a2ui-row>     가로 배치
│   └─ ui/card.ts ─────── <a2ui-card>   카드 컨테이너
│
├─ [입력 컴포넌트]
│   ├─ ui/text-field.ts ── <a2ui-textfield>  텍스트 입력
│   ├─ ui/checkbox.ts ──── <a2ui-checkbox>   체크박스
│   ├─ ui/slider.ts ─────── <a2ui-slider>    슬라이더
│   ├─ ui/datetime-input.ts <a2ui-datetimeinput> 날짜/시간
│   └─ ui/multiple-choice.ts <a2ui-multiplechoice> 선택지
│
├─ [표시 컴포넌트]
│   ├─ ui/text.ts ─────── <a2ui-text>    텍스트 (h1~h6, body)
│   ├─ ui/image.ts ─────── <a2ui-image>  이미지
│   ├─ ui/icon.ts ─────── <a2ui-icon>   아이콘
│   ├─ ui/divider.ts ───── <a2ui-divider> 구분선
│   ├─ ui/list.ts ─────── <a2ui-list>   동적/정적 리스트
│   └─ ui/tabs.ts ─────── <a2ui-tabs>   탭 패널
│
├─ [인터랙션 컴포넌트]
│   ├─ ui/button.ts ───── <a2ui-button>  버튼 (a2uiaction 이벤트 발생)
│   └─ ui/modal.ts ─────── <a2ui-modal>  모달 다이얼로그
│
├─ [미디어 컴포넌트]
│   ├─ ui/audio.ts ─────── <a2ui-audioplayer> 오디오
│   └─ ui/video.ts ─────── <a2ui-video>  비디오
│
└─ [핵심 처리]
    ├─ data/signal-model-processor.ts
    │     createSignalA2uiMessageProcessor()
    │     Signal 기반 반응형 메시지 프로세서
    │
    └─ events/
        └─ a2ui.ts  ── a2uiaction 이벤트 정의
                        버튼 클릭 → 서버 전송
```

### 5.2 Lit 이벤트 흐름 (버튼 클릭 → 서버 → 화면 갱신)

```
사용자가 <a2ui-button> 클릭
         │
         ▼
button.ts: dispatchEvent(new CustomEvent("a2uiaction", { detail: action }))
         │
         ▼
app.ts: @a2uiaction 이벤트 리스너
    └── context 수집 (evt.detail.action.context 배열 순회)
         │  ├─ literalString/Number/Boolean → 그대로 사용
         │  └─ path → processor.getData(path) 로 데이터 모델에서 조회
         │
         ▼
A2UIClientEventMessage 생성:
{
  userAction: {
    name: "book_restaurant",
    surfaceId: "default",
    sourceComponentId: "book-btn",
    context: { restaurantName: "Jing Fong", address: "..." }
  }
}
         │
         ▼
A2UIClient.send(message)
    └── DataPart로 포장 → A2AClient.sendMessage()
         │
         ▼ [서버 처리...]
         │
         ▼
messages[] 반환 (DataPart 배열)
         │
         ▼
processor.clearSurfaces()
processor.processMessages(messages)
    └── surfaceUpdate  → surface 컴포넌트 트리 업데이트
    └── dataModelUpdate → 데이터 모델 업데이트
    └── beginRendering  → 렌더링 시작 신호
         │
         ▼
Signal 변경 감지 → LitElement 자동 re-render
→ <a2ui-surface> → <a2ui-root> → 각 컴포넌트 렌더링
```

---

## 6. Flutter 클라이언트 아키텍처

```
╔═══════════════════════════════════════════════════════════════╗
║     samples/client/flutter/restaurant_shell/lib/              ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  main.dart                                                    ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ main() → runApp(RestaurantShellApp)                    │  ║
║  │                                                        │  ║
║  │ RestaurantShellApp (StatefulWidget)                    │  ║
║  │   └── MaterialApp(                                    │  ║
║  │         home: ChatScreen(onToggleTheme: _toggleTheme))│  ║
║  │                                                        │  ║
║  │ ChatScreen (StatefulWidget)                            │  ║
║  │   ├── A2uiMessageProcessor _processor                 │  ║
║  │   │     package:genui_a2ui                            │  ║
║  │   │     CoreCatalogItems.asCatalog() 사용             │  ║
║  │   │                                                    │  ║
║  │   ├── A2uiContentGenerator _generator                 │  ║
║  │   │     serverUrl: Uri.parse(config.serverUrl)        │  ║
║  │   │     ← AGENT_URL dart-define 주입                  │  ║
║  │   │                                                    │  ║
║  │   ├── GenUiConversation _conversation                  │  ║
║  │   │     contentGenerator + a2uiMessageProcessor        │  ║
║  │   │                                                    │  ║
║  │   ├── _generator.textResponseStream.listen(...)       │  ║
║  │   │     텍스트 응답 수신 → setState()                  │  ║
║  │   │                                                    │  ║
║  │   ├── _generator.errorStream.listen(...)               │  ║
║  │   │     에러 처리 → _netError 표시                     │  ║
║  │   │                                                    │  ║
║  │   └── build()                                         │  ║
║  │       ├── _AppBar        앱 상단바                     │  ║
║  │       ├── _AppSwitcher   Restaurant ↔ Contacts 전환   │  ║
║  │       ├── _ErrorBanner   네트워크 에러 배너            │  ║
║  │       ├── Expanded:                                    │  ║
║  │       │   ├─ (응답 전) _buildWelcomeView()            │  ║
║  │       │   │   ├── _HeroImage                          │  ║
║  │       │   │   └── _SuggestionGrid                     │  ║
║  │       │   └─ (응답 후) _buildSurfaceView()            │  ║
║  │       │       └── _FullSurfaceCard                    │  ║
║  │       │             └── GenUiSurface(                 │  ║
║  │       │                   host: _processor,           │  ║
║  │       │                   surfaceId: "default")       │  ║
║  │       └── _InputBar      하단 입력바                  │  ║
║  └────────────────────────────────────────────────────────┘  ║
╚═══════════════════════════════════════════════════════════════╝
```

### 6.1 Flutter 핵심 패키지

```
pubspec.yaml 의존성:
┌────────────────────────────────────────────────────────────┐
│  genui         → GenUiConversation, GenUiSurface           │
│                  (A2UI Flutter 렌더러 메인 패키지)          │
│                                                            │
│  genui_a2ui    → A2uiMessageProcessor, A2uiContentGenerator│
│                  CoreCatalogItems                          │
│                  (A2UI 프로토콜 처리 레이어)                │
└────────────────────────────────────────────────────────────┘
```

### 6.2 Flutter 클래스 역할

```
A2uiContentGenerator (genui_a2ui)
  ┌──────────────────────────────────────────────────────┐
  │ serverUrl 로 에이전트 서버에 HTTP 요청               │
  │ A2A 프로토콜 메시지 송수신 처리                      │
  │                                                      │
  │ Streams:                                             │
  │   textResponseStream → 텍스트 응답                   │
  │   errorStream        → 에러 정보                     │
  └──────────────────────────────────────────────────────┘

A2uiMessageProcessor (genui_a2ui)
  ┌──────────────────────────────────────────────────────┐
  │ 서버에서 받은 A2UI 메시지를 파싱해 내부 모델로 변환  │
  │ Surface / Component 상태 관리                        │
  │ catalogs: [CoreCatalogItems.asCatalog()]             │
  └──────────────────────────────────────────────────────┘

GenUiConversation (genui)
  ┌──────────────────────────────────────────────────────┐
  │ contentGenerator + a2uiMessageProcessor 연결          │
  │ sendRequest(UserMessage.text(t)) → 메시지 전송        │
  └──────────────────────────────────────────────────────┘

GenUiSurface (genui)
  ┌──────────────────────────────────────────────────────┐
  │ host: processor (A2uiMessageProcessor)               │
  │ surfaceId: "default"                                 │
  │ → processor 의 Surface 상태를 Flutter Widget으로 렌더링│
  └──────────────────────────────────────────────────────┘
```

### 6.3 Flutter 이벤트 흐름

```
사용자가 텍스트 입력 후 전송
         │
         ▼
_submit(text) in ChatScreen
    └── _conversation.sendRequest(UserMessage.text(t))
         │
         ▼
GenUiConversation → A2uiContentGenerator
    └── HTTP POST to AGENT_URL (localhost:10002 또는 실제 IP)
         │  Headers: X-A2A-Extensions: a2ui/v0.8
         │
         ▼ [서버 처리...]
         │
         ▼
A2uiContentGenerator → A2uiMessageProcessor.processMessages()
         │
         ▼
setState(() {
  _hasReceivedResponse = true;
  _responseVersion++;  ← AnimatedSwitcher 트리거
})
         │
         ▼
_buildSurfaceView() 렌더링
    └── GenUiSurface(host: _processor, surfaceId: "default")
         └── processor 내부 Surface 상태로부터 Flutter 위젯 트리 생성
```

### 6.4 Flutter 안드로이드 연결 방식

```
┌─────────────────────────────────────────────────────────┐
│           Android 기기별 AGENT_URL 설정                  │
├───────────────────┬─────────────────────────────────────┤
│ Chrome (웹)       │ http://localhost:10002              │
│ Android 에뮬레이터 │ http://10.0.2.2:10002              │
│ 실물 기기 (USB)   │ adb reverse → localhost:10002        │
│ 실물 기기 (Wi-Fi) │ http://[호스트 LAN IP]:10002         │
└───────────────────┴─────────────────────────────────────┘

run-demo-restaurant-flutter.sh 에서 자동 감지:
  flutter devices → Android/emulator/chrome 구분
  → --dart-define=AGENT_URL=http://[감지된 주소]:10002
```

---

## 7. 서버 ↔ 클라이언트 실제 통신 흐름

### 7.1 전체 시퀀스 다이어그램

```
사용자         Lit/Flutter 클라이언트      에이전트 서버          OpenAI
  │                    │                       │                    │
  │ "뉴욕 중식당 보여줘"│                       │                    │
  │──────────────────▶│                       │                    │
  │                    │                       │                    │
  │                    │ POST /.well-known/    │                    │
  │                    │ agent-card.json       │                    │
  │                    │──────────────────────▶│                    │
  │                    │◀── AgentCard (a2ui    │                    │
  │                    │    extension 포함)    │                    │
  │                    │                       │                    │
  │                    │ POST /                │                    │
  │                    │ X-A2A-Extensions:     │                    │
  │                    │   a2ui/v0.8           │                    │
  │                    │ DataPart OR TextPart  │                    │
  │                    │──────────────────────▶│                    │
  │                    │                       │                    │
  │         [working]  │◀── TaskState.working  │                    │
  │ "맛집 찾는 중..."  │                       │                    │
  │◀──────────────────│                       │                    │
  │                    │                  try_activate_a2ui_extension()
  │                    │                  → use_ui = True
  │                    │                       │                    │
  │                    │                  runner.run_async()        │
  │                    │                       │──────────────────▶│
  │                    │                       │ system_prompt +    │
  │                    │                       │ A2UI schema +      │
  │                    │                       │ examples           │
  │                    │                       │                    │
  │                    │                       │ tool call:         │
  │                    │                       │◀─ get_restaurants  │
  │                    │                       │──────── JSON ─────▶│
  │                    │                       │◀── restaurant list  │
  │                    │                       │                    │
  │                    │                       │◀── A2UI JSON 응답 ─│
  │                    │                       │  <a2ui>[...]</a2ui>│
  │                    │                       │                    │
  │                    │                  parse_response() 파싱
  │                    │                  schema validator 검증
  │                    │                  parse_response_to_parts()
  │                    │                       │                    │
  │                    │◀── DataPart[]         │                    │
  │                    │    (A2UI JSON parts)  │                    │
  │                    │                       │                    │
  │           processor.processMessages()      │                    │
  │           → surfaceUpdate 처리             │                    │
  │           → dataModelUpdate 처리           │                    │
  │           → beginRendering 처리            │                    │
  │                    │                       │                    │
  │  [레스토랑 목록 UI]│                       │                    │
  │◀──────────────────│                       │                    │
  │                    │                       │                    │
  │ [예약하기] 클릭    │                       │                    │
  │──────────────────▶│                       │                    │
  │                    │                       │                    │
  │             a2uiaction 이벤트              │                    │
  │             → context 수집                │                    │
  │             → userAction 메시지 생성       │                    │
  │                    │                       │                    │
  │                    │ POST /                │                    │
  │                    │ DataPart {userAction} │                    │
  │                    │──────────────────────▶│                    │
  │                    │                       │                    │
  │                    │                  action = "book_restaurant"
  │                    │                  → 예약 폼 UI 생성 요청   │
  │                    │                       │──────────────────▶│
  │                    │                       │◀── 예약 폼 A2UI JSON│
  │                    │                       │                    │
  │  [예약 폼 UI 표시] │◀── DataPart[] ────────│                    │
  │◀──────────────────│                       │                    │
```

### 7.2 Lit vs Flutter: 클라이언트 구현 비교

```
┌─────────────────────────────────────────────────────────────────┐
│                  핵심 구현 비교표                                  │
├──────────────────────┬──────────────────┬────────────────────────┤
│ 기능                 │ Lit              │ Flutter                │
├──────────────────────┼──────────────────┼────────────────────────┤
│ 언어/프레임워크       │ TypeScript + Lit │ Dart + Flutter         │
├──────────────────────┼──────────────────┼────────────────────────┤
│ A2A 클라이언트       │ @a2a-js/sdk      │ genui_a2ui 패키지       │
│                      │ A2AClient        │ A2uiContentGenerator   │
├──────────────────────┼──────────────────┼────────────────────────┤
│ 메시지 프로세서       │ createSignal     │ A2uiMessageProcessor   │
│                      │ A2uiMessage      │ (genui_a2ui)           │
│                      │ Processor()      │                        │
├──────────────────────┼──────────────────┼────────────────────────┤
│ Surface 렌더링        │ <a2ui-surface>   │ GenUiSurface           │
│                      │ Web Component    │ Flutter Widget         │
├──────────────────────┼──────────────────┼────────────────────────┤
│ 반응형 업데이트       │ Lit Signal       │ setState()             │
│                      │ (자동 re-render) │ (AnimatedSwitcher)     │
├──────────────────────┼──────────────────┼────────────────────────┤
│ Extension 헤더        │ client.ts 에서   │ genui_a2ui 내부        │
│ (X-A2A-Extensions)   │ 직접 추가        │ 자동 처리              │
├──────────────────────┼──────────────────┼────────────────────────┤
│ userAction 전송       │ @a2uiaction      │ 패키지 내부 처리       │
│                      │ 이벤트 핸들링    │                        │
├──────────────────────┼──────────────────┼────────────────────────┤
│ 플랫폼               │ 웹 브라우저      │ 웹 + Android + iOS     │
├──────────────────────┼──────────────────┼────────────────────────┤
│ 서버 포트             │ 5173             │ 8080 (web-server mode) │
├──────────────────────┼──────────────────┼────────────────────────┤
│ 디버그               │ 브라우저 DevTools │ Flutter DevTools        │
│                      │ /debug 로그 뷰어 │ Client Logs 패널       │
└──────────────────────┴──────────────────┴────────────────────────┘
```

---

## 8. 컴포넌트 연결 맵

### 8.1 전체 코드 연결 그래프

```
┌─────────────────────────────────────────────────────────────────┐
│                      코드 연결 전체 맵                            │
└─────────────────────────────────────────────────────────────────┘

[서버 진입점]
__main__.py:main()
    │
    ├──▶ RestaurantAgent (agent.py:RestaurantAgent)
    │         │
    │         ├── A2uiSchemaManager (agent_sdks/python/src/a2ui/core/schema/manager.py)
    │         │       └── generate_system_prompt() → LLM에 A2UI 스키마/예제 주입
    │         │
    │         ├── LlmAgent → Runner (google.adk)
    │         │       └── get_restaurants (tools.py:get_restaurants)
    │         │               └── restaurant_data.json → JSON 반환
    │         │
    │         └── stream()
    │               ├── parse_response (a2ui/core/parser/parser.py:parse_response)
    │               │       └── <a2ui>...</a2ui> 태그 파싱
    │               ├── validator.validate() (a2ui/core/schema/validator.py)
    │               └── parse_response_to_parts (a2ui/a2a.py:parse_response_to_parts)
    │                       └── create_a2ui_part() → DataPart
    │
    ├──▶ RestaurantAgentExecutor (agent_executor.py:RestaurantAgentExecutor)
    │         │
    │         ├── try_activate_a2ui_extension (a2ui/a2a.py:try_activate_a2ui_extension)
    │         │       └── X-A2A-Extensions 헤더 확인 → use_ui 결정
    │         │
    │         └── execute() → TaskUpdater → event_queue → 클라이언트 전송
    │
    └──▶ A2AStarletteApplication (a2a.server.apps)
              ├── /.well-known/agent-card.json  (AgentCard 공개)
              ├── /                              (메인 A2A 엔드포인트)
              ├── /static                        (이미지 서빙)
              └── /debug, /debug/stream          (SSE 로그 뷰어)

[Lit 클라이언트]
index.html → <a2ui-shell>
    │
    └── app.ts:A2UILayoutEditor
          │
          ├── client.ts:A2UIClient.send()
          │       └── @a2a-js/sdk:A2AClient.fromCardUrl()
          │               └── Header: X-A2A-Extensions → 서버에 UI 모드 요청
          │
          ├── @a2ui/lit:v0_8.Data.createSignalA2uiMessageProcessor()
          │       └── processMessages(messages)
          │             ├── surfaceUpdate  → surface 컴포넌트 등록
          │             ├── dataModelUpdate → Signal 상태 업데이트
          │             └── beginRendering  → 렌더링 시작
          │
          └── <a2ui-surface> (renderers/lit/src/0.8/ui/surface.ts)
                └── <a2ui-root> → <a2ui-column> → <a2ui-list> → ...
                      └── <a2ui-button>
                            └── @click → dispatchEvent("a2uiaction")
                                  └── app.ts @a2uiaction → A2UIClient.send()

[Flutter 클라이언트]
main.dart:main() → RestaurantShellApp
    │
    └── ChatScreen
          │
          ├── A2uiContentGenerator (genui_a2ui)
          │       └── HTTP POST to AGENT_URL
          │               └── Header: X-A2A-Extensions 자동 포함
          │
          ├── A2uiMessageProcessor (genui_a2ui)
          │       └── processMessages(messages)
          │             └── CoreCatalogItems 기반 컴포넌트 매핑
          │
          ├── GenUiConversation (genui)
          │       └── sendRequest(UserMessage.text(t))
          │               └── contentGenerator 통해 서버 호출
          │
          └── GenUiSurface (genui)
                └── host: _processor, surfaceId: "default"
                      └── processor 상태 → Flutter Widget 트리
```

### 8.2 A2UI 메시지 처리 흐름 (코드 레벨)

```
[Lit] 메시지 처리 체인:
───────────────────────
DataPart[] 수신
    │
    ▼
app.ts: processor.processMessages(messages)
    │   (renderers/lit/src/0.8/data/signal-model-processor.ts)
    │
    ├─ surfaceUpdate → surface에 컴포넌트 등록
    │                   component-registry.ts 에서 타입별 클래스 조회
    │
    ├─ dataModelUpdate → Signal 업데이트
    │                     Signal 변경 → 해당 컴포넌트 자동 re-render
    │
    └─ beginRendering → root 컴포넌트 ID 설정
                         <a2ui-surface>.surfaceId 로 렌더링 시작

[Flutter] 메시지 처리 체인:
─────────────────────────
DataPart[] 수신 (genui_a2ui 패키지 내부)
    │
    ▼
A2uiMessageProcessor.processMessages()
    │
    ├─ createSurface / surfaceUpdate → SurfaceModel 생성
    ├─ updateDataModel / dataModelUpdate → DataModel 업데이트
    └─ beginRendering → 렌더링 플래그 설정
         │
         ▼
GenUiSurface 위젯 (genui)
    └─ processor 상태 구독 → setState() → 위젯 재빌드
         └─ surfaceId: "default" 의 컴포넌트 트리 → Flutter 위젯 매핑
```

---

## 9. 코드 레퍼런스 색인

### 서버 사이드 (Python)

| 파일 | 클래스/함수 | 역할 |
|------|------------|------|
| [`samples/agent/adk/restaurant_finder/__main__.py`](../samples/agent/adk/restaurant_finder/__main__.py) | `main()` | A2A 서버 진입점, uvicorn 실행 |
| [`samples/agent/adk/restaurant_finder/agent.py`](../samples/agent/adk/restaurant_finder/agent.py) | `RestaurantAgent` | LLM 에이전트, A2UI 스키마 검증, 스트리밍 |
| [`samples/agent/adk/restaurant_finder/agent.py`](../samples/agent/adk/restaurant_finder/agent.py) | `RestaurantAgent.stream()` | LLM 호출 → A2UI JSON 추출 → 검증 → Part 반환 |
| [`samples/agent/adk/restaurant_finder/agent_executor.py`](../samples/agent/adk/restaurant_finder/agent_executor.py) | `RestaurantAgentExecutor` | A2A 요청 오케스트레이터 |
| [`samples/agent/adk/restaurant_finder/agent_executor.py`](../samples/agent/adk/restaurant_finder/agent_executor.py) | `RestaurantAgentExecutor.execute()` | 입력 파싱, 에이전트 선택, Task 이벤트 발행 |
| [`samples/agent/adk/restaurant_finder/tools.py`](../samples/agent/adk/restaurant_finder/tools.py) | `get_restaurants()` | LLM이 호출하는 레스토랑 데이터 조회 Tool |
| [`agent_sdks/python/src/a2ui/a2a.py`](../agent_sdks/python/src/a2ui/a2a.py) | `try_activate_a2ui_extension()` | X-A2A-Extensions 헤더 → UI 모드 활성화 |
| [`agent_sdks/python/src/a2ui/a2a.py`](../agent_sdks/python/src/a2ui/a2a.py) | `parse_response_to_parts()` | LLM 출력 → A2A DataPart 배열 변환 |
| [`agent_sdks/python/src/a2ui/a2a.py`](../agent_sdks/python/src/a2ui/a2a.py) | `get_a2ui_agent_extension()` | AgentCard extension 설정 생성 |
| [`agent_sdks/python/src/a2ui/core/schema/manager.py`](../agent_sdks/python/src/a2ui/core/schema/manager.py) | `A2uiSchemaManager` | 스키마 로드 + 시스템 프롬프트 생성 |
| [`agent_sdks/python/src/a2ui/core/parser/parser.py`](../agent_sdks/python/src/a2ui/core/parser/parser.py) | `parse_response()` | `<a2ui>...</a2ui>` 태그 파싱 |

### Lit 클라이언트 (TypeScript)

| 파일 | 클래스/함수 | 역할 |
|------|------------|------|
| [`samples/client/lit/shell/app.ts`](../samples/client/lit/shell/app.ts) | `A2UILayoutEditor` | 메인 Web Component, 전체 앱 상태 관리 |
| [`samples/client/lit/shell/app.ts`](../samples/client/lit/shell/app.ts) | `#sendAndProcessMessage()` | 서버 호출 + 메시지 처리 통합 함수 |
| [`samples/client/lit/shell/client.ts`](../samples/client/lit/shell/client.ts) | `A2UIClient` | A2A SDK 래퍼, X-A2A-Extensions 헤더 주입 |
| [`samples/client/lit/shell/client.ts`](../samples/client/lit/shell/client.ts) | `A2UIClient.send()` | A2A 메시지 전송 + 응답 파싱 |
| [`samples/client/lit/shell/middleware/a2a.ts`](../samples/client/lit/shell/middleware/a2a.ts) | `plugin()` | Vite 개발서버 A2A 프록시 플러그인 |
| [`renderers/lit/src/0.8/ui/ui.ts`](../renderers/lit/src/0.8/ui/ui.ts) | `A2UITagNameMap` | 전체 컴포넌트 태그 맵 |
| [`renderers/lit/src/0.8/ui/surface.ts`](../renderers/lit/src/0.8/ui/surface.ts) | `Surface` | Surface 최상위 컨테이너 |
| [`renderers/lit/src/0.8/ui/button.ts`](../renderers/lit/src/0.8/ui/button.ts) | `Button` | 버튼 (a2uiaction 이벤트 발생) |
| [`renderers/lit/src/0.8/core.ts`](../renderers/lit/src/0.8/core.ts) | `Data.createSignalA2uiMessageProcessor` | Signal 기반 메시지 프로세서 생성 |
| [`renderers/lit/src/0.8/data/signal-model-processor.ts`](../renderers/lit/src/0.8/data/signal-model-processor.ts) | `createSignalA2uiMessageProcessor()` | 반응형 Signal로 메시지 상태 관리 |

### Flutter 클라이언트 (Dart)

| 파일 | 클래스/함수 | 역할 |
|------|------------|------|
| [`samples/client/flutter/restaurant_shell/lib/main.dart`](../samples/client/flutter/restaurant_shell/lib/main.dart) | `RestaurantShellApp` | 루트 Flutter 앱 위젯 |
| [`samples/client/flutter/restaurant_shell/lib/main.dart`](../samples/client/flutter/restaurant_shell/lib/main.dart) | `ChatScreen` | 메인 화면, 대화 + UI 렌더링 관리 |
| [`samples/client/flutter/restaurant_shell/lib/main.dart`](../samples/client/flutter/restaurant_shell/lib/main.dart) | `_ChatScreenState._initClient()` | generator/conversation 초기화 |
| [`samples/client/flutter/restaurant_shell/lib/main.dart`](../samples/client/flutter/restaurant_shell/lib/main.dart) | `_ChatScreenState._submit()` | 메시지 전송 트리거 |
| [`samples/client/flutter/restaurant_shell/lib/main.dart`](../samples/client/flutter/restaurant_shell/lib/main.dart) | `_FullSurfaceCard` | GenUiSurface 래퍼 Widget |
| [`samples/client/flutter/restaurant_shell/lib/config/app_config.dart`](../samples/client/flutter/restaurant_shell/lib/config/app_config.dart) | `AppConfig` | 앱 설정 (serverUrl, title 등) |
| [`samples/client/flutter/restaurant_shell/lib/config/app_config.dart`](../samples/client/flutter/restaurant_shell/lib/config/app_config.dart) | `restaurantConfig` | Restaurant 데모 설정 (AGENT_URL 주입) |

### 데모 실행 스크립트

| 파일 | 역할 |
|------|------|
| [`demos/run-demo-restaurant-lit.sh`](../demos/run-demo-restaurant-lit.sh) | Agent + Lit 클라이언트 동시 실행 |
| [`demos/run-demo-restaurant-flutter.sh`](../demos/run-demo-restaurant-flutter.sh) | Agent + Flutter 클라이언트 동시 실행 |
| [`demos/scripts/run-agent-restaurant.sh`](../demos/scripts/run-agent-restaurant.sh) | Agent만 단독 실행 |
| [`demos/scripts/run-client-lit.sh`](../demos/scripts/run-client-lit.sh) | Lit 클라이언트만 단독 실행 |
| [`demos/scripts/run-client-flutter-shell.sh`](../demos/scripts/run-client-flutter-shell.sh) | Flutter 클라이언트만 단독 실행 |

---

## 빠른 참고: 핵심 포트와 URL

```
┌──────────────────────────────────────────────────────────────┐
│                    서비스 포트 맵                              │
├────────────────────────┬──────────���──────────────────────────┤
│ localhost:10002        │ Restaurant 에이전트 서버             │
│ localhost:10002/debug  │ 실시간 LLM 로그 뷰어 (브라우저)     │
│ localhost:5173         │ Lit 클라이언트 (npm run dev)         │
│ localhost:8080         │ Flutter 웹 클라이언트                │
│ localhost:10003        │ Contact 에이전트 서버                │
└────────────────────────┴─────────────────────────────────────┘
```

---

> **관련 문서**
>
> - [A2UI 공식 사이트](https://a2ui.org/)
> - [A2UI란 무엇인가](introduction/what-is-a2ui.md)
> - [데이터 흐름 개념](concepts/data-flow.md)
> - [컴포넌트 구조](concepts/components.md)
> - [에이전트 개발 가이드](guides/agent-development.md)
> - [학습 가이드 (한국어)](learning/README.ko.md)
