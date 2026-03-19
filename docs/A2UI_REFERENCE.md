# A2UI 종합 참조 문서

> **A2UI (Agent-to-User Interface)** — AI 에이전트가 안전하게 Rich UI를 생성하는 오픈 표준
> **버전:** v0.8 Stable / v0.9 Draft / v0.10 개발 중
> **라이선스:** Apache 2.0

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [전체 디렉토리 구조](#2-전체-디렉토리-구조)
3. [핵심 개념](#3-핵심-개념)
4. [컴포넌트 카탈로그](#4-컴포넌트-카탈로그)
5. [프로토콜 메시지 스펙](#5-프로토콜-메시지-스펙)
6. [워크플로우 및 데이터 흐름](#6-워크플로우-및-데이터-흐름)
7. [에이전트 SDK](#7-에이전트-sdk)
8. [렌더러](#8-렌더러)
9. [샘플 및 데모](#9-샘플-및-데모)
10. [개발 도구](#10-개발-도구)
11. [트랜스포트 옵션](#11-트랜스포트-옵션)
12. [보안 아키텍처](#12-보안-아키텍처)
13. [버전별 비교](#13-버전별-비교)
14. [개발자 경로 가이드](#14-개발자-경로-가이드)
15. [테스트 및 검증](#15-테스트-및-검증)
16. [핵심 파일 위치 색인](#16-핵심-파일-위치-색인)

---

## 1. 프로젝트 개요

### 목적

A2UI는 **AI 에이전트가 실행 가능한 코드(HTML/JavaScript) 대신 선언적 JSON 형식의 UI 설명을 전송**하고, 클라이언트가 자신의 네이티브 컴포넌트 라이브러리로 렌더링하는 오픈 표준입니다.

### 핵심 철학

| 원칙 | 설명 |
|------|------|
| **Security First** | 선언적 데이터 형식, 코드 실행 없음 |
| **LLM-Friendly** | 평탄한 구조, 점진적 생성 가능 |
| **Framework-Agnostic** | 웹(Angular, Lit, React), 모바일(Flutter), 데스크탑 지원 |
| **Flexibility** | 커스텀 컴포넌트 카탈로그 지원 |

### 전통적 방식 vs A2UI

```
❌ 기존 방식: 에이전트가 HTML/JavaScript 생성
"Here's a booking form: <form>...</form><script>...</script>"
→ 보안 취약, 스타일 불일치, 사용자 데이터 노출 위험

✅ A2UI: 에이전트가 선언적 JSON 전송
{"component": "Form", "children": ["date-field", "guest-field"]}
→ 클라이언트가 자신의 네이티브 UI로 안전하게 렌더링
```

---

## 2. 전체 디렉토리 구조

```
a2ui/
├── README.md                    # 프로젝트 개요 및 빠른 시작
├── mkdocs.yaml                  # 문서 사이트 설정 (MkDocs Material 테마)
├── CONTRIBUTING.md              # 기여 가이드 (CLA, 스타일 가이드)
│
├── docs/                        # 완전한 문서 체계 (40+ 파일)
│   ├── index.md                 # 메인 포털
│   ├── quickstart.md            # 5분 시작 가이드
│   ├── roadmap.md               # 로드맵
│   ├── concepts/                # 핵심 개념 문서
│   ├── reference/               # API 참조
│   ├── guides/                  # 개발 가이드
│   ├── introduction/            # 소개 자료
│   └── learning/                # 한글 초보자 학습 자료 (6개)
│
├── specification/               # 프로토콜 스펙
│   ├── v0_8/                    # Stable
│   │   ├── docs/                # 스펙 문서
│   │   ├── json/                # JSON 스키마 + 29개 예제
│   │   └── eval/                # TypeScript 검증 도구
│   ├── v0_9/                    # Draft
│   │   ├── docs/                # 업그레이드된 스펙
│   │   ├── json/                # v0.9 스키마
│   │   └── eval/                # Genkit 기반 검증 도구
│   └── v0_10/                   # 개발 중
│       ├── docs/
│       ├── json/
│       ├── eval/
│       └── test/                # 테스트 케이스
│
├── agent_sdks/                  # 에이전트 SDK
│   ├── python/                  # Python SDK
│   │   └── src/a2ui/
│   │       ├── core/            # 스키마 관리, 검증, 수정
│   │       ├── basic_catalog/   # 기본 카탈로그 구현
│   │       ├── a2a/             # A2A 통합
│   │       └── adk/             # ADK 통합
│   └── java/                    # Java SDK
│
├── samples/                     # 샘플 코드
│   ├── agent/                   # 에이전트 샘플
│   │   ├── adk/                 # ADK 기반 샘플 (5개 데모)
│   │   └── mcp/                 # MCP 통합 샘플
│   ├── client/                  # 클라이언트 샘플
│   │   ├── lit/                 # Lit (Web Components)
│   │   ├── angular/             # Angular
│   │   ├── react/               # React
│   │   └── flutter/             # Flutter
│   └── personalized_learning/   # 맞춤형 학습 데모
│
├── renderers/                   # UI 렌더러
│   ├── web_core/                # 공유 핵심 라이브러리
│   ├── lit/                     # Lit 렌더러
│   ├── angular/                 # Angular 렌더러
│   ├── react/                   # React 렌더러
│   ├── flutter/                 # Flutter GenUI SDK
│   └── markdown/                # Markdown 렌더러
│
├── demos/                       # 통합 데모 시스템
│   ├── run-demo-*.sh            # 데모 실행 스크립트
│   ├── scripts/                 # 에이전트/클라이언트 분리 실행
│   └── .env.example             # 환경 설정 템플릿
│
└── tools/                       # 개발 도구
    ├── composer/                # AI 기반 A2UI 위젯 빌더
    ├── inspector/               # A2UI 응답 시각화
    ├── editor/                  # UI 생성 + 라이브 미리보기
    └── build_catalog/           # 카탈로그 번들링 도구
```

---

## 3. 핵심 개념

### 3.1 Adjacency List 모델 (평탄한 컴포넌트 트리)

LLM이 깊게 중첩된 트리를 생성하기 어려운 문제를 해결합니다.

```json
// ❌ 중첩 방식 - LLM이 생성하기 어려움
{
  "id": "root",
  "children": [
    {
      "id": "header",
      "children": [
        { "id": "title", "text": "예약" }
      ]
    }
  ]
}

// ✅ 평탄 리스트 방식 - LLM 친화적 + 증분 업데이트 가능
{
  "components": [
    { "id": "root",   "component": "Column", "children": ["header", "body"] },
    { "id": "header", "component": "Column", "children": ["title"] },
    { "id": "title",  "component": "Text",   "text": "예약" },
    { "id": "body",   "component": "Column", "children": ["date-field", "guest-field"] }
  ]
}
```

### 3.2 JSON Pointer 기반 데이터 바인딩

RFC 6901 표준 경로로 데이터와 컴포넌트를 연결합니다.

```
/user/name           → user 객체의 name 속성
/cart/items/0        → items 배열의 첫 번째 원소
/reservation/guests  → reservation 객체의 guests 속성
```

**동적 리스트 렌더링:**

```json
{
  "id": "restaurant-list",
  "component": "List",
  "children": {
    "template": {
      "dataBinding": "/restaurants",      // 배열 경로
      "componentId": "restaurant-card"    // 각 항목용 템플릿 ID
    }
  }
}
```

### 3.3 Surface (표면)

Surface는 에이전트가 관리하는 하나의 UI 영역입니다.

- 각 Surface는 고유한 `surfaceId`로 식별
- 하나의 에이전트가 여러 Surface 동시 관리 가능
- Surface마다 독립적인 컴포넌트 트리와 데이터 모델 보유

### 3.4 컴포넌트 카탈로그

카탈로그는 에이전트가 사용할 수 있는 컴포넌트 목록을 JSON Schema로 정의합니다.

```json
{
  "catalogId": "basic",
  "version": "1.0",
  "components": {
    "Button": {
      "properties": {
        "text": { "type": "string" },
        "action": { "$ref": "#/definitions/Action" }
      }
    }
  }
}
```

### 3.5 스트리밍 메시지

에이전트는 JSONL(줄 구분 JSON) 형식으로 메시지를 순차적으로 스트리밍합니다.

```jsonl
{"surfaceUpdate": {"surfaceId": "booking", "components": [...]}}
{"dataModelUpdate": {"surfaceId": "booking", "path": "/reservation", "contents": [...]}}
{"beginRendering": {"surfaceId": "booking", "root": "root"}}
```

---

## 4. 컴포넌트 카탈로그

### 4.1 표준 컴포넌트 (Basic Catalog)

#### 레이아웃

| 컴포넌트 | 역할 | 주요 속성 |
|---------|------|----------|
| `Row` | 가로 배치 컨테이너 | `children`, `alignment` |
| `Column` | 세로 배치 컨테이너 | `children`, `alignment` |
| `List` | 스크롤 가능 리스트 | `children`, `template` |
| `Card` | 카드 컨테이너 | `children`, `elevation` |

#### 입력 컴포넌트

| 컴포넌트 | 역할 | 주요 속성 |
|---------|------|----------|
| `TextField` | 텍스트 입력 | `text` (data binding), `placeholder`, `label` |
| `CheckBox` | 체크박스 | `checked` (data binding), `label` |
| `RadioButton` | 라디오 버튼 | `selected` (data binding), `options` |
| `Slider` | 슬라이더 | `value` (data binding), `min`, `max` |
| `DateTimeInput` | 날짜/시간 선택 | `value` (data binding), `format` |
| `Dropdown` | 드롭다운 선택 | `value` (data binding), `options` |

#### 출력 컴포넌트

| 컴포넌트 | 역할 | 주요 속성 |
|---------|------|----------|
| `Text` | 텍스트 표시 | `text`, `style` (heading/body/caption) |
| `Image` | 이미지 | `src`, `alt`, `width`, `height` |
| `Button` | 버튼 | `text`, `action`, `style` |
| `Link` | 하이퍼링크 | `text`, `url` |
| `Icon` | 아이콘 | `name`, `size`, `color` |

#### 고급 컴포넌트

| 컴포넌트 | 역할 | 주요 속성 |
|---------|------|----------|
| `Tab` | 탭 인터페이스 | `tabs`, `activeTab` |
| `Dialog` | 모달 다이얼로그 | `title`, `content`, `actions` |
| `Divider` | 구분선 | `orientation`, `thickness` |
| `ProgressBar` | 진행 표시 | `value`, `max` |
| `Chip` | 태그/칩 | `text`, `removable` |

### 4.2 실제 예제 목록 (29개)

`/specification/v0_8/json/catalogs/basic/examples/`

| 예제 파일 | 설명 |
|----------|------|
| `flight-status.json` | 항공편 상태 카드 |
| `email-compose.json` | 이메일 작성 폼 |
| `calendar-day.json` | 캘린더 하루 뷰 |
| `restaurant-card.json` | 레스토랑 정보 카드 |
| `music-player.json` | 음악 플레이어 |
| `product-card.json` | 상품 카드 |
| `login-form.json` | 로그인 폼 |
| `weather-widget.json` | 날씨 위젯 |
| `task-card.json` | 작업 카드 |
| `user-profile.json` | 사용자 프로필 |
| `purchase-confirmation.json` | 구매 확인 |
| `contact-form.json` | 연락처 폼 |
| ... (총 29개) | |

### 4.3 커스텀 카탈로그

사용자 정의 컴포넌트를 카탈로그로 등록할 수 있습니다.

```json
{
  "catalogId": "rizzcharts",
  "version": "1.0",
  "components": {
    "Chart": {
      "properties": {
        "type": { "enum": ["bar", "line", "pie"] },
        "data": { "type": "object" },
        "title": { "type": "string" }
      }
    },
    "StockTicker": {
      "properties": {
        "symbol": { "type": "string" },
        "refreshInterval": { "type": "number" }
      }
    }
  }
}
```

**예제:** `/samples/agent/adk/rizzcharts/rizzcharts_catalog_definition.json`

---

## 5. 프로토콜 메시지 스펙

### 5.1 v0.8 메시지 타입

#### `surfaceUpdate` — 컴포넌트 트리 정의/업데이트

```json
{
  "surfaceUpdate": {
    "surfaceId": "booking",
    "components": [
      {
        "id": "root",
        "component": { "Column": { "children": { "explicitList": ["header", "form"] } } }
      },
      {
        "id": "header",
        "component": { "Text": { "text": { "literal": "레스토랑 예약" } } }
      },
      {
        "id": "date-field",
        "component": {
          "TextField": {
            "label": { "literal": "날짜" },
            "text": { "path": "/reservation/date" }
          }
        }
      }
    ]
  }
}
```

#### `dataModelUpdate` — 데이터 값 업데이트

```json
{
  "dataModelUpdate": {
    "surfaceId": "booking",
    "path": "/reservation",
    "contents": [
      { "key": "date", "valueString": "2025-12-16" },
      { "key": "time", "valueString": "19:00" },
      { "key": "guests", "valueString": "2" }
    ]
  }
}
```

#### `beginRendering` — 렌더링 시작 신호

```json
{
  "beginRendering": {
    "surfaceId": "booking",
    "root": "root"
  }
}
```

#### `deleteSurface` — Surface 삭제

```json
{
  "deleteSurface": {
    "surfaceId": "booking"
  }
}
```

### 5.2 v0.9 메시지 타입 (개선됨)

#### `createSurface` — Surface 명시적 생성 (beginRendering 대체)

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "booking",
    "catalog": "basic",
    "root": "root"
  }
}
```

#### `updateComponents` — 컴포넌트 업데이트 (surfaceUpdate 대체)

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "booking",
    "components": [
      {
        "id": "root",
        "component": "Column",
        "children": ["header", "form"]
      },
      {
        "id": "header",
        "component": "Text",
        "text": "레스토랑 예약"
      }
    ]
  }
}
```

#### `updateDataModel` — 데이터 업데이트 (dataModelUpdate 대체)

```json
{
  "version": "v0.9",
  "updateDataModel": {
    "surfaceId": "booking",
    "path": "/reservation",
    "data": {
      "date": "2025-12-16",
      "time": "19:00",
      "guests": 2
    }
  }
}
```

### 5.3 클라이언트 → 에이전트: 사용자 액션

```json
{
  "userAction": {
    "name": "confirm",
    "surfaceId": "booking",
    "context": {
      "details": {
        "date": "2025-12-16",
        "time": "19:00",
        "guests": "3",
        "specialRequests": "창가 자리 요청"
      }
    }
  }
}
```

---

## 6. 워크플로우 및 데이터 흐름

### 6.1 전체 시스템 아키텍처

```
┌──────────────────────────────────────────────────────────────────┐
│                        사용자 상호작용                             │
│                   (채팅 입력, 버튼 클릭 등)                        │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                ┌───────────▼───────────┐
                │     클라이언트 앱      │
                │  ┌─────────────────┐  │
                │  │  채팅 UI        │  │
                │  │  (사용자 입력)   │  │
                │  └────────┬────────┘  │
                │           │           │
                │  ┌────────▼────────┐  │
                │  │ MessageProcessor│  │  ← web_core
                │  │ (파싱/검증/상태) │  │
                │  └────────┬────────┘  │
                │           │           │
                │  ┌────────▼────────┐  │
                │  │  렌더러 레이어  │  │
                │  │ (Lit/Angular/   │  │
                │  │  React/Flutter) │  │
                │  └────────┬────────┘  │
                │           │           │
                │  ┌────────▼────────┐  │
                │  │  네이티브 UI    │  │
                │  │  컴포넌트들     │  │
                │  └─────────────────┘  │
                └───────────┬───────────┘
                            │ 사용자 액션 (userAction)
              ┌─────────────▼─────────────┐
              │         트랜스포트         │
              │    (A2A / SSE / WebSocket) │
              └─────────────┬─────────────┘
                            │
                ┌───────────▼───────────┐
                │      에이전트          │
                │  ┌─────────────────┐  │
                │  │   LLM 호출      │  │
                │  │  (GPT/Gemini)   │  │
                │  └────────┬────────┘  │
                │           │           │
                │  ┌────────▼────────┐  │
                │  │  A2UI SDK       │  │
                │  │ (생성/검증/수정) │  │
                │  └────────┬────────┘  │
                │           │           │
                │  ┌────────▼────────┐  │
                │  │  JSONL 스트림   │  │
                │  │  (A2UI 메시지)  │  │
                │  └─────────────────┘  │
                └───────────────────────┘
```

### 6.2 Restaurant Booking 전체 워크플로우

```
사용자: "내일 7시에 2명 예약 잡아줘"
         │
         ▼
[1] 에이전트: LLM으로 의도 파악 → A2UI 구조 생성
    ↓ JSONL 스트리밍

[2] surfaceUpdate 전송
    - root (Column)
      - header (Text: "레스토랑 예약")
      - form (Column)
        - date-field (TextField ← /reservation/date)
        - time-field (TextField ← /reservation/time)
        - guests-field (TextField ← /reservation/guests)
        - confirm-btn (Button: "예약 확정")

[3] dataModelUpdate 전송
    /reservation/date    = "2025-12-16"
    /reservation/time    = "19:00"
    /reservation/guests  = "2"

[4] beginRendering 전송
    → 클라이언트가 UI를 사용자에게 표시

[5] 사용자: guests 필드를 "3"으로 수정
    → 데이터 바인딩 자동 업데이트 (재요청 없음)

[6] 사용자: "예약 확정" 버튼 클릭
    → userAction 전송
    {
      "name": "confirm",
      "context": {
        "details": { "date": "...", "time": "...", "guests": "3" }
      }
    }

[7] 에이전트: 예약 API 호출 → 성공
    → deleteSurface 또는 확인 Surface로 업데이트
```

### 6.3 다중 Surface 워크플로우

```
에이전트
  │
  ├─ Surface "contact-1" → 홍길동 연락처 카드
  ├─ Surface "contact-2" → 이순신 연락처 카드
  └─ Surface "search-bar" → 검색 입력 UI

각 Surface는 독립적으로 생성/업데이트/삭제 가능
```

### 6.4 오케스트레이터 패턴 워크플로우

```
사용자
  │
  ▼
메인 에이전트 (Orchestrator)
  │
  ├─ 원격 에이전트 A (Restaurant Finder) 호출
  │    └─ A2UI 메시지 생성 → 메인 에이전트에게 반환
  │
  ├─ 원격 에이전트 B (Weather) 호출
  │    └─ A2UI 메시지 생성 → 메인 에이전트에게 반환
  │
  └─ A2UI 메시지 합치거나 패스스루 → 클라이언트
```

---

## 7. 에이전트 SDK

### 7.1 Python SDK 구조

**위치:** `/agent_sdks/python/src/a2ui/`

```
a2ui/
├── core/
│   ├── schema/
│   │   ├── manager.py       # A2uiSchemaManager
│   │   │                    # - 카탈로그 로드
│   │   │                    # - 스키마 관리
│   │   │                    # - 컴포넌트 정의 조회
│   │   │
│   │   ├── validator.py     # A2uiValidator
│   │   │                    # - JSON Schema 검증
│   │   │                    # - 오류 보고
│   │   │
│   │   ├── catalog.py       # A2uiCatalog, CatalogConfig
│   │   │                    # - 카탈로그 로드/파싱
│   │   │                    # - 메타데이터 관리
│   │   │
│   │   └── payload_fixer.py # LLM 출력 자동 수정
│   │                        # - 잘못된 JSON 수정
│   │                        # - 스키마 불일치 보정
│   │
├── basic_catalog/
│   └── provider.py          # BasicCatalog 구현체
│                            # - 표준 컴포넌트 제공
│
├── a2a/
│   └── a2a.py               # A2A Part 생성 유틸리티
│                            # - A2UI → A2A Part 변환
│
└── adk/
    └── send_a2ui_to_client_toolset.py
                             # ADK 통합
                             # - Tool로 A2UI 전송
                             # - 에이전트 콜백 연결
```

### 7.2 Python SDK 사용 예제

```python
from a2ui import A2uiSchemaManager, BasicCatalog

# 카탈로그 초기화
catalog = BasicCatalog()
manager = A2uiSchemaManager(catalog)

# A2UI 메시지 생성 (LLM 프롬프트에 스키마 포함)
schema_prompt = manager.get_schema_prompt()
# → LLM에 전달하여 올바른 A2UI JSON 생성 유도

# 검증
validator = manager.get_validator()
result = validator.validate(a2ui_message)

# 자동 수정
fixer = manager.get_payload_fixer()
fixed_message = fixer.fix(raw_llm_output)
```

### 7.3 ADK 통합 패턴

```python
from google.adk import Agent
from a2ui.adk import send_a2ui_to_client_toolset

agent = Agent(
    name="restaurant_finder",
    toolsets=[send_a2ui_to_client_toolset],
    # ...
)

# 에이전트가 A2UI를 도구로 사용하여 클라이언트에 전송
```

---

## 8. 렌더러

### 8.1 렌더러 지원 매트릭스

| 렌더러 | 플랫폼 | v0.8 | v0.9 | 상태 |
|--------|--------|:----:|:----:|------|
| **Lit** | 웹 (Web Components) | ✅ | ✅ | 안정 |
| **Angular** | 웹 | ✅ | ✅ | 안정 |
| **React** | 웹 | ✅ | ❌ | 안정 |
| **Flutter** (GenUI SDK) | 모바일/데스크탑/웹 | ✅ | ✅ | 안정 |
| **Markdown** | 문서 | ✅ | - | 지원 |
| **SwiftUI** | iOS/macOS | - | - | Q2 2026 예정 |
| **Jetpack Compose** | Android | - | - | Q2 2026 예정 |

### 8.2 web_core — 공유 핵심 라이브러리

**위치:** `/renderers/web_core/`

모든 웹 렌더러가 공유하는 핵심 로직 (3,000+ 줄)

| 클래스/모듈 | 역할 |
|------------|------|
| `MessageProcessor` | A2UI JSONL 스트림 파싱 및 처리 |
| `SurfaceModel` | 단일 Surface 상태 관리 |
| `SurfaceGroupModel` | 여러 Surface 그룹 관리 |
| `DataModel` | 데이터 값 저장 |
| `DataContext` | JSON Pointer 경로 해석, 데이터 바인딩 |
| `ComponentModel` | 컴포넌트 트리 상태 |
| `SchemaValidator` | JSON Schema 검증 |
| `ExpressionParser` | 클라이언트 함수 평가 (v0.9) |

### 8.3 Lit 렌더러

**위치:** `/renderers/lit/`

```
lit/
├── src/
│   ├── components/      # 각 컴포넌트 구현 (LitElement)
│   │   ├── a2ui-text.ts
│   │   ├── a2ui-button.ts
│   │   ├── a2ui-text-field.ts
│   │   ├── a2ui-list.ts
│   │   └── ...
│   ├── styles/          # CSS 스타일
│   └── index.ts         # 진입점
└── package.json
```

### 8.4 Angular 렌더러

**위치:** `/renderers/angular/`

```
angular/
└── projects/a2ui/
    ├── src/
    │   ├── lib/
    │   │   ├── components/  # Angular 컴포넌트들
    │   │   ├── directives/  # 데이터 바인딩 디렉티브
    │   │   └── services/    # MessageProcessor 서비스
    │   └── public-api.ts    # 공개 API
    └── package.json
```

### 8.5 React 렌더러

**위치:** `/renderers/react/`

```
react/
├── src/
│   ├── components/      # React 컴포넌트들
│   ├── hooks/           # 커스텀 훅 (useA2ui, useSurface 등)
│   └── index.ts
└── package.json
```

### 8.6 Flutter 렌더러 (GenUI SDK)

**위치:** `/renderers/flutter/`

```
flutter/
├── lib/
│   ├── src/
│   │   ├── widgets/     # Flutter 위젯 구현
│   │   ├── models/      # 데이터 모델
│   │   └── parsers/     # A2UI JSON 파싱
│   └── gen_ui.dart      # 공개 API
├── pubspec.yaml
└── install-flutter-sdk.sh  # Flutter SDK 자동 설치
```

---

## 9. 샘플 및 데모

### 9.1 에이전트 샘플 개요

**위치:** `/samples/agent/adk/`

| 샘플 | 디렉토리 | 설명 | 특징 |
|------|---------|------|------|
| **Restaurant Finder** | `restaurant_finder/` | 레스토랑 검색 + 예약 | 기본 데모, OpenAI |
| **Contact Lookup** | `contact_lookup/` | 연락처 검색 + 결과 리스트 | 동적 리스트 렌더링 |
| **Contact Multiple Surfaces** | `contact_multiple_surfaces/` | 여러 연락처 동시 표시 | 다중 Surface |
| **Rizzcharts** | `rizzcharts/` | 커스텀 차트 컴포넌트 | 커스텀 카탈로그 |
| **Orchestrator** | `orchestrator/` | 원격 에이전트 조정 | 멀티에이전트 |
| **Component Gallery** | `component_gallery/` | 모든 컴포넌트 정적 전시 | LLM 없음 |

### 9.2 클라이언트 샘플 개요

**위치:** `/samples/client/`

| 프레임워크 | 데모들 |
|-----------|-------|
| **Lit** | shell, restaurant, contact, component_gallery |
| **Angular** | restaurant, contact, rizzcharts, orchestrator |
| **React** | shell |
| **Flutter** | restaurant |

### 9.3 데모 실행 방법

```bash
# 1. 환경 설정
cd demos/
cp .env.example .env
# .env에 OPENAI_API_KEY 설정

# 2. 통합 실행 (에이전트 + 클라이언트 한번에)
./run-demo-restaurant-lit.sh
./run-demo-restaurant-angular.sh
./run-demo-restaurant-react.sh
./run-demo-restaurant-flutter.sh
./run-demo-contact-lit.sh
./run-demo-rizzcharts-angular.sh
./run-demo-orchestrator-angular.sh
./run-demo-component-gallery-lit.sh

# 3. 분리 실행 (터미널 2개)
# 터미널 1: 에이전트
./scripts/run-agent-restaurant.sh
# 터미널 2: 클라이언트
./scripts/run-client-lit-restaurant.sh
```

### 9.4 Personalized Learning 샘플

**위치:** `/samples/personalized_learning/`

- AI 기반 개인화 학습 경험 데모
- 기술 스택: Jupyter Notebook + TypeScript + Python
- 특징: 학습자 수준에 맞게 A2UI로 동적 콘텐츠 생성

---

## 10. 개발 도구

### 10.1 A2UI Composer

**위치:** `/tools/composer/`
**배포:** https://a2ui-editor.ag-ui.com

| 항목 | 내용 |
|------|------|
| **목적** | AI 기반 A2UI 위젯 빌더 |
| **기능** | 자연어 설명 → A2UI JSON 자동 생성 |
| **기술** | CopilotKit + Gemini/OpenAI |
| **사용법** | 자연어로 UI 설명 → JSON 출력 확인 |

### 10.2 A2UI Inspector

**위치:** `/tools/inspector/`
**포트:** 기본 5173

| 항목 | 내용 |
|------|------|
| **목적** | A2UI 응답 시각화 도구 |
| **기능** | JSON 직접 입력 → 렌더링 결과 실시간 표시 |
| **사용법** | `npm run dev` → 브라우저에서 JSON 붙여넣기 |

### 10.3 A2UI Editor

**위치:** `/tools/editor/`

| 항목 | 내용 |
|------|------|
| **목적** | A2UI 응답 생성 및 라이브 미리보기 |
| **기능** | Gemini로 UI 생성 + 즉시 렌더링 확인 |
| **필수 환경** | `GEMINI_API_KEY` |

### 10.4 build_catalog

**위치:** `/tools/build_catalog/`

| 항목 | 내용 |
|------|------|
| **목적** | 카탈로그 번들링 도구 |
| **기능** | 외부 `$ref` 통합 → 독립형 JSON Schema 생성 |
| **사용법** | `uv run build_catalog.py <카탈로그 경로>` |

---

## 11. 트랜스포트 옵션

### 11.1 지원 방식 비교

| 트랜스포트 | 상태 | 사용 사례 | 특징 |
|-----------|:----:|---------|------|
| **A2A Protocol** | ✅ Stable | 멀티에이전트 | 보안 기반 에이전트 통신, 인증 내장 |
| **AG UI** | ✅ Stable | Full-stack React | CopilotKit 기반 양방향 실시간 |
| **REST/SSE** | 💡 Proposed | 간단한 HTTP | Server-Sent Events로 단방향 스트리밍 |
| **WebSocket** | 💡 Proposed | 실시간 양방향 | 지속적 연결, 낮은 레이턴시 |
| **gRPC** | 💡 Custom | 고성능 | 커스텀 구현 필요 |

### 11.2 A2A 바인딩 구조

```
A2A 메시지
  └─ Part (type: "data")
       └─ content: A2UI JSON 메시지
            ├─ surfaceUpdate / updateComponents
            ├─ dataModelUpdate / updateDataModel
            └─ beginRendering / createSurface
```

**메타데이터 헤더:**
```
X-A2UI-Catalog: basic
X-A2UI-Client-Capabilities: {...}
```

---

## 12. 보안 아키텍처

### 12.1 선언적 접근법의 보안 이점

```
❌ 위험 시나리오 (기존 HTML 생성):
에이전트 → HTML/JS → 클라이언트 실행
  "Here's your form: <script>steal(document.cookie)</script>"
  → XSS, CSRF, 데이터 탈취 가능

✅ A2UI 보안 모델:
에이전트 → JSON 선언 → 클라이언트 제어 렌더링
  {"component": "Button", "action": {"name": "submit"}}
  → 사전 등록된 핸들러만 실행, 임의 코드 실행 불가
```

### 12.2 보안 계층

| 계층 | 메커니즘 | 역할 |
|------|---------|------|
| **컴포넌트 화이트리스트** | 카탈로그 정의 | 카탈로그에 없는 컴포넌트는 렌더링 거부 |
| **스키마 검증** | JSON Schema | 컴포넌트 형식 강제 |
| **액션 핸들러** | 사전 등록 | 등록된 핸들러만 실행 |
| **Content Security Policy** | 브라우저 | XSS 방어 |
| **샌드박스** | iframe/shadow DOM | 커스텀 컴포넌트 격리 |

### 12.3 클라이언트 기능 선언 (v0.9)

클라이언트가 자신이 지원하는 기능을 에이전트에게 선언:

```json
{
  "supportedCatalogs": ["basic", "rizzcharts"],
  "supportedTransports": ["sse", "websocket"],
  "clientFunctions": ["formatDate", "calculateTotal"],
  "platform": "web",
  "locale": "ko-KR"
}
```

→ 에이전트가 클라이언트 능력에 맞는 UI만 생성

---

## 13. 버전별 비교

### 13.1 v0.8 vs v0.9 메시지 형식 비교

| 측면 | v0.8 | v0.9 |
|------|------|------|
| **버전 필드** | 없음 | `"version": "v0.9"` 필수 |
| **Surface 생성** | `beginRendering`에서 암묵적 | `createSurface`로 명시적 분리 |
| **컴포넌트 업데이트** | `surfaceUpdate` | `updateComponents` |
| **데이터 업데이트** | `dataModelUpdate` | `updateDataModel` |
| **컴포넌트 형식** | `{"Text": {"text": {...}}}` | `"Text"` (문자열) |
| **자식 참조** | `{"explicitList": [...]}` | 배열 `[...]` |
| **카탈로그 지정** | `beginRendering`에서 선택적 | `createSurface`에서 필수 |
| **클라이언트 함수** | ❌ 미지원 | ✅ `CustomFunction` 지원 |

### 13.2 v0.8 → v0.9 마이그레이션

**참조:** `/specification/v0_9/docs/evolution_guide.md`

```jsonl
// v0.8
{"surfaceUpdate": {"surfaceId": "s1", "components": [{"id": "btn", "component": {"Button": {"text": {"literal": "확인"}}}}]}}
{"beginRendering": {"surfaceId": "s1", "root": "btn"}}

// v0.9 동일 기능
{"version": "v0.9", "createSurface": {"surfaceId": "s1", "catalog": "basic", "root": "btn"}}
{"version": "v0.9", "updateComponents": {"surfaceId": "s1", "components": [{"id": "btn", "component": "Button", "text": "확인"}]}}
```

### 13.3 현재 개발 상태

| 버전 | 상태 | 주요 특징 |
|------|------|---------|
| **v0.8** | ✅ Stable | 모든 렌더러 지원, 프로덕션 사용 가능 |
| **v0.9** | 🔶 Draft | 개선된 문법, 클라이언트 함수, Lit/Angular 지원 |
| **v0.10** | 🔧 개발 중 | 미정 |

---

## 14. 개발자 경로 가이드

### Path 1: 프론트엔드 (클라이언트 앱 빌드)

```
1. 렌더러 선택
   ├─ Lit       → @a2ui/lit       (웹, 가볍고 빠름)
   ├─ Angular   → @a2ui/angular   (엔터프라이즈 규모)
   ├─ React     → @a2ui/react     (주류 생태계)
   └─ Flutter   → GenUI SDK       (크로스플랫폼)

2. 설치 및 설정
   npm install @a2ui/lit

3. MessageProcessor 구성
   const processor = new MessageProcessor({catalog: 'basic'})

4. Surface 컴포넌트 통합
   <a2ui-surface .processor={processor}></a2ui-surface>

5. 에이전트 연결 (SSE/WebSocket/A2A)
   processor.connect('http://agent-url/stream')
```

**참고 파일:**
- `/docs/guides/client-setup.md`
- `/samples/client/lit/shell/` (예제)
- `/samples/client/angular/` (Angular 예제)

### Path 2: 백엔드 (에이전트 빌드)

```
1. 에이전트 프레임워크 선택
   ├─ Python ADK  → Google Agent Development Kit (권장)
   ├─ Node.js     → A2A SDK / Vercel AI SDK
   └─ 기타        → 자유로운 구현

2. Python ADK 예제
   pip install google-adk a2ui

3. 카탈로그 스키마를 LLM 프롬프트에 포함
   manager = A2uiSchemaManager(BasicCatalog())
   prompt = manager.get_schema_prompt()

4. 구조화된 출력으로 A2UI JSON 생성

5. 검증 + 자동 수정
   fixed = fixer.fix(raw_output)
   validator.validate(fixed)

6. JSONL 스트리밍으로 클라이언트에 전송
```

**참고 파일:**
- `/docs/guides/agent-development.md`
- `/samples/agent/adk/restaurant_finder/` (레스토랑 예제)
- `/agent_sdks/python/` (Python SDK)

### Path 3: 기존 프레임워크 활용

| 프레임워크 | 적합한 경우 |
|-----------|-----------|
| **AG UI / CopilotKit** | React 풀스택, 빠른 프로토타이핑 |
| **Flutter GenUI SDK** | 크로스플랫폼 모바일/데스크탑 |

### Path 4: 커스텀 렌더러 개발

```
1. web_core 라이브러리 기반 시작
2. MessageProcessor 상속/활용
3. 각 컴포넌트 매핑 구현
4. 카탈로그 등록
```

**참고 파일:**
- `/docs/guides/renderer-development.md`
- `/renderers/lit/` (참조 구현)

---

## 15. 테스트 및 검증

### 15.1 사양 검증 도구 (v0.8)

**위치:** `/specification/v0_8/eval/`

| 파일 | 역할 |
|------|------|
| `basic_schema_matcher.ts` | 기본 메시지 형식 검증 |
| `message_type_matcher.ts` | 메시지 타입 확인 |
| `schema_matcher.ts` | 스키마 호환성 검사 |
| `surface_update_schema_matcher.ts` | Surface 업데이트 메시지 검증 |

### 15.2 사양 검증 도구 (v0.9)

**위치:** `/specification/v0_9/eval/`

| 파일 | 역할 |
|------|------|
| `generator.ts` | 테스트용 A2UI 메시지 생성 |
| `validator.ts` | 메시지 검증 |
| `evaluator.ts` | 전체 평가 흐름 실행 |
| `analysis_flow.ts` | 분석 및 리포팅 |

### 15.3 테스트 케이스

**위치:** `/specification/v0_10/test/cases/`

| 파일 | 테스트 내용 |
|------|-----------|
| `button_checks.json` | 버튼 컴포넌트 검증 |
| `checkable_components.json` | 체크박스/라디오 버튼 |
| `client_messages.json` | 클라이언트 메시지 형식 |
| `contact_form_example.jsonl` | 연락처 폼 전체 시나리오 |
| `function_catalog_validation.json` | 함수 카탈로그 |
| `tabs_checks.json` | 탭 컴포넌트 |
| `text_variants.json` | 텍스트 변형 |
| `theme_validation.json` | 테마 검증 |

### 15.4 Python SDK 테스트

**위치:** `/agent_sdks/python/tests/`

```bash
cd agent_sdks/python
uv run pytest
```

---

## 16. 핵심 파일 위치 색인

### 문서

| 파일 | 내용 |
|------|------|
| `/README.md` | 프로젝트 개요, 빠른 시작 |
| `/mkdocs.yaml` | 문서 사이트 설정 |
| `/docs/index.md` | 문서 포털 |
| `/docs/quickstart.md` | 5분 시작 가이드 |
| `/docs/roadmap.md` | 개발 로드맵 |
| `/docs/concepts/overview.md` | 핵심 개념 개요 |
| `/docs/concepts/data-flow.md` | 데이터 흐름 |
| `/docs/concepts/components.md` | 컴포넌트 모델 |
| `/docs/concepts/data-binding.md` | 데이터 바인딩 |
| `/docs/concepts/catalogs.md` | 카탈로그 개념 |
| `/docs/concepts/transports.md` | 트랜스포트 옵션 |
| `/docs/guides/client-setup.md` | 클라이언트 설정 가이드 |
| `/docs/guides/agent-development.md` | 에이전트 개발 가이드 |
| `/docs/guides/renderer-development.md` | 렌더러 개발 가이드 |

### 한글 학습 자료

| 파일 | 내용 |
|------|------|
| `/docs/learning/01-quick-start.ko.md` | 빠른 시작 |
| `/docs/learning/02-end-to-end-flow.ko.md` | 전체 흐름 |
| `/docs/learning/03-agent-internals.ko.md` | 에이전트 내부 |
| `/docs/learning/04-client-rendering.ko.md` | 클라이언트 렌더링 |
| `/docs/learning/05-troubleshooting.ko.md` | 문제 해결 |
| `/docs/learning/06-repo-map.ko.md` | 저장소 구조 |

### 사양

| 파일 | 내용 |
|------|------|
| `/specification/v0_8/docs/a2ui_protocol.md` | v0.8 프로토콜 스펙 |
| `/specification/v0_8/json/standard_catalog_definition.json` | 표준 카탈로그 |
| `/specification/v0_9/docs/a2ui_protocol.md` | v0.9 프로토콜 스펙 |
| `/specification/v0_9/docs/evolution_guide.md` | v0.8→v0.9 마이그레이션 |
| `/specification/v0_9/docs/a2ui_custom_functions.md` | 커스텀 함수 스펙 |
| `/specification/v0_9/json/a2ui_client_capabilities.json` | 클라이언트 기능 스키마 |

### 코드

| 파일/디렉토리 | 내용 |
|-------------|------|
| `/agent_sdks/python/src/a2ui/` | Python SDK 소스 |
| `/renderers/web_core/` | 공유 웹 핵심 라이브러리 |
| `/renderers/lit/` | Lit 렌더러 |
| `/renderers/angular/projects/a2ui/` | Angular 렌더러 |
| `/renderers/react/src/` | React 렌더러 |
| `/renderers/flutter/lib/` | Flutter 렌더러 |

### 샘플

| 디렉토리 | 내용 |
|---------|------|
| `/samples/agent/adk/restaurant_finder/` | Restaurant Finder 에이전트 |
| `/samples/agent/adk/contact_lookup/` | Contact Lookup 에이전트 |
| `/samples/agent/adk/rizzcharts/` | 커스텀 차트 에이전트 |
| `/samples/agent/adk/orchestrator/` | 오케스트레이터 에이전트 |
| `/samples/client/lit/shell/` | Lit 클라이언트 쉘 |
| `/samples/client/angular/` | Angular 클라이언트들 |

### 도구

| 디렉토리 | 내용 |
|---------|------|
| `/tools/composer/` | AI 위젯 빌더 |
| `/tools/inspector/` | A2UI 시각화 도구 |
| `/tools/editor/` | Gemini 기반 UI 에디터 |
| `/tools/build_catalog/` | 카탈로그 번들러 |
| `/demos/run-demo-*.sh` | 통합 데모 실행 스크립트 |

---

## 부록: 용어 정의

| 용어 | 정의 |
|------|------|
| **Surface** | 에이전트가 관리하는 하나의 UI 영역, `surfaceId`로 식별 |
| **Catalog** | 사용 가능한 컴포넌트를 JSON Schema로 정의한 목록 |
| **Adjacency List** | 평탄한 ID 참조 방식의 컴포넌트 트리 표현 |
| **JSON Pointer** | RFC 6901 표준, 데이터 경로 표현 (e.g., `/user/name`) |
| **Data Binding** | 컴포넌트 속성과 데이터 모델 경로의 연결 |
| **JSONL** | 줄 구분 JSON 형식, A2UI 스트리밍에 사용 |
| **Transport** | 에이전트와 클라이언트 간 메시지 전달 방식 |
| **A2A** | Agent-to-Agent 프로토콜, 에이전트 간 통신 표준 |
| **AG UI** | Agentic UI 프로토콜, CopilotKit 기반 |
| **ADK** | Agent Development Kit, Google의 에이전트 개발 프레임워크 |
| **GenUI SDK** | Flutter 기반 생성형 UI SDK |
| **web_core** | 모든 웹 렌더러가 공유하는 핵심 TypeScript 라이브러리 |

---

*마지막 업데이트: 2026-03-19*
*저장소: https://github.com/google/A2UI*
