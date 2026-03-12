# 03. Agent 내부 구조 이해

## Restaurant Finder

### 핵심 파일

- 엔트리: `samples/agent/adk/restaurant_finder/__main__.py`
- 실행 오케스트레이션: `samples/agent/adk/restaurant_finder/agent_executor.py`
- LLM/A2UI 처리: `samples/agent/adk/restaurant_finder/agent.py`
- 도구: `samples/agent/adk/restaurant_finder/tools.py`

### 꼭 알아야 할 3가지

1. **UI 모드 vs 텍스트 모드**
   - A2UI extension이 활성화되면 UI agent를 사용
   - 아니면 text agent 사용
2. **A2UI 검증 재시도**
   - schema validation 실패 시 재프롬프트 후 재시도
3. **서버 측 보정 로직**
   - booking form 필드/표면(surface) 보정으로 렌더 안정화

## Orchestrator

### 핵심 파일

- 엔트리: `samples/agent/adk/orchestrator/__main__.py`
- executor: `samples/agent/adk/orchestrator/agent_executor.py`
- 라우팅 로직: `samples/agent/adk/orchestrator/agent.py`

### 핵심 개념

- `surfaceId -> subagent_name` 매핑 저장
- 이후 userAction 발생 시 동일 surface를 만든 subagent로 강제 라우팅

## Rizzcharts

### 핵심 파일

- 엔트리: `samples/agent/adk/rizzcharts/__main__.py`
- 에이전트: `samples/agent/adk/rizzcharts/agent.py`

### 핵심 개념

- 질의 의도 분류(차트 vs 지도)
- 데이터 도구 호출
- A2UI JSON 생성 후 toolset으로 client 전송

