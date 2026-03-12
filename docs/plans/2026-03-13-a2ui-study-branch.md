# A2UI Study Branch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A2UI 레포를 처음 보는 학습자가 데모 실행과 핵심 코드 흐름을 한국어 중심으로 빠르게 이해할 수 있도록 학습용 주석/문서/가이드를 추가한다.

**Architecture:** 핵심 실행 경로(`demos` → `agent_executor`/`agent` → `client surface`)는 코드 내부 docstring으로 깊게 설명하고, 레포 전반은 `docs/learning` 허브 문서로 구조화한다. 기능 로직은 변경하지 않고, 이해를 돕는 설명/흐름 문서/점검 체크리스트를 중심으로 강화한다.

**Tech Stack:** Python (ADK/A2A/A2UI), Flutter, Shell scripts, Markdown (Mermaid)

---

### Task 1: 학습 허브 문서 뼈대 만들기

**Files:**
- Create: `docs/learning/README.ko.md`
- Create: `docs/learning/01-quick-start.ko.md`
- Create: `docs/learning/02-end-to-end-flow.ko.md`
- Create: `docs/learning/03-agent-internals.ko.md`
- Create: `docs/learning/04-client-rendering.ko.md`
- Create: `docs/learning/05-troubleshooting.ko.md`
- Test: `docs/learning/*.md` (링크/섹션 수동 확인)

**Step 1: Write the failing test**

```python
def test_learning_docs_exist():
    # pseudo: 파일이 없으므로 실패해야 함
    assert False
```

**Step 2: Run test to verify it fails**

Run: `python - <<'PY'\nfrom pathlib import Path\nfiles=[\n'docs/learning/README.ko.md',\n'docs/learning/01-quick-start.ko.md',\n'docs/learning/02-end-to-end-flow.ko.md',\n'docs/learning/03-agent-internals.ko.md',\n'docs/learning/04-client-rendering.ko.md',\n'docs/learning/05-troubleshooting.ko.md']\nprint(all(Path(f).exists() for f in files))\nPY`
Expected: `False`

**Step 3: Write minimal implementation**

```markdown
# docs/learning/README.ko.md
- 학습 순서
- 필수 실행 명령
- 용어 사전 링크
```

**Step 4: Run test to verify it passes**

Run: 위 Python one-liner 재실행
Expected: `True`

**Step 5: Commit**

```bash
git add docs/learning
git commit -m "docs(learning): add Korean learning navigation set"
```

### Task 2: Restaurant 핵심 Python 실행 흐름 주석화

**Files:**
- Modify: `samples/agent/adk/restaurant_finder/agent_executor.py`
- Modify: `samples/agent/adk/restaurant_finder/agent.py`
- Modify: `samples/agent/adk/restaurant_finder/tools.py`
- Test: `samples/agent/adk/restaurant_finder` (import/실행 확인)

**Step 1: Write the failing test**

```python
def test_executor_has_detailed_docstring():
    import inspect
    from agent_executor import RestaurantAgentExecutor
    assert "userAction" in inspect.getdoc(RestaurantAgentExecutor.execute)
```

**Step 2: Run test to verify it fails**

Run: `cd samples/agent/adk/restaurant_finder && uv run python - <<'PY'\nimport inspect\nfrom agent_executor import RestaurantAgentExecutor\nprint('userAction' in (inspect.getdoc(RestaurantAgentExecutor.execute) or ''))\nPY`
Expected: `False` (초기 상태 기준)

**Step 3: Write minimal implementation**

```python
class RestaurantAgentExecutor(AgentExecutor):
    async def execute(...):
        """A2A 요청을 받아 userAction/텍스트를 해석하고, A2UI parts를 반환한다.
        ...
        """
```

**Step 4: Run test to verify it passes**

Run: 위 스니펫 재실행
Expected: `True`

**Step 5: Commit**

```bash
git add samples/agent/adk/restaurant_finder
git commit -m "docs(restaurant_finder): add Korean flow docstrings for executor and agent"
```

### Task 3: Orchestrator/Rizzcharts 핵심 포인트 주석화

**Files:**
- Modify: `samples/agent/adk/orchestrator/agent_executor.py`
- Modify: `samples/agent/adk/orchestrator/agent.py`
- Modify: `samples/agent/adk/rizzcharts/agent.py`
- Test: 각 모듈 import 가능 여부

**Step 1: Write the failing test**

```python
def test_orchestrator_route_doc_present():
    import inspect
    from agent import OrchestratorAgent
    assert "surfaceId" in inspect.getdoc(
        OrchestratorAgent.programmtically_route_user_action_to_subagent
    )
```

**Step 2: Run test to verify it fails**

Run: `cd samples/agent/adk/orchestrator && uv run python - <<'PY'\nimport inspect\nfrom agent import OrchestratorAgent\nprint('surfaceId' in (inspect.getdoc(OrchestratorAgent.programmtically_route_user_action_to_subagent) or ''))\nPY`
Expected: `False` (초기 상태 기준)

**Step 3: Write minimal implementation**

```python
@classmethod
async def programmtically_route_user_action_to_subagent(...):
    """userAction.surfaceId를 기반으로 해당 surface를 만든 subagent로 라우팅한다."""
```

**Step 4: Run test to verify it passes**

Run: 위 스니펫 재실행
Expected: `True`

**Step 5: Commit**

```bash
git add samples/agent/adk/orchestrator samples/agent/adk/rizzcharts
git commit -m "docs(orchestrator): explain A2UI route mapping and subagent flow"
```

### Task 4: 데모 실행 스크립트/Flutter 설정 학습 주석화

**Files:**
- Modify: `demos/run-demo.sh`
- Modify: `demos/scripts/load-env.sh`
- Modify: `demos/scripts/run-agent-restaurant.sh`
- Modify: `demos/scripts/run-client-flutter-shell.sh`
- Modify: `samples/client/flutter/restaurant_shell/pubspec.yaml`
- Modify: `samples/client/flutter/restaurant_shell/lib/main.dart`
- Test: shell syntax + flutter analyze (가능 범위)

**Step 1: Write the failing test**

```python
def test_run_demo_has_learning_comments():
    text = Path("demos/run-demo.sh").read_text()
    assert "학습 포인트" in text
```

**Step 2: Run test to verify it fails**

Run: `python - <<'PY'\nfrom pathlib import Path\nprint('학습 포인트' in Path('demos/run-demo.sh').read_text())\nPY`
Expected: `False`

**Step 3: Write minimal implementation**

```bash
# 학습 포인트:
# - run-demo.sh는 어떤 wrapper를 호출하는지 먼저 이해하면 전체 흐름이 보입니다.
```

**Step 4: Run test to verify it passes**

Run: 위 Python 스니펫 재실행
Expected: `True`

**Step 5: Commit**

```bash
git add demos samples/client/flutter/restaurant_shell
git commit -m "docs(demos): add Korean learning comments for demo orchestration"
```

### Task 5: 실행 검증 + 최종 통합 문서 정리 + PR

**Files:**
- Modify: `docs/learning/*.md` (검증 결과 반영)
- Test: 데모 최소 1개 실행 (`restaurant-flutter` 또는 `restaurant-lit`)

**Step 1: Write the failing test**

```python
def test_quick_start_contains_verified_commands():
    text = Path("docs/learning/01-quick-start.ko.md").read_text()
    assert "검증 완료" in text
```

**Step 2: Run test to verify it fails**

Run: 위 유사 스니펫
Expected: `False`

**Step 3: Write minimal implementation**

```markdown
## 검증 완료
- [x] run-demo.sh restaurant-flutter
```

**Step 4: Run test to verify it passes**

Run: 재확인
Expected: `True`

**Step 5: Commit**

```bash
git add docs/learning
git commit -m "docs(learning): add verified runbook and troubleshooting map"
```

