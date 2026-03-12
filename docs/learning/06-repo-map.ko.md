# 06. 레포 맵 (Directory Map)

레포를 처음 보면 파일 수가 많아 길을 잃기 쉽습니다.  
아래는 "무엇을 언제 보면 되는지" 기준의 실용 맵입니다.

## 최우선(실행/학습 직결)

- `demos/`
  - `run-demo.sh`: 데모 라우터
  - `run-demo-*.sh`: 개별 데모 실행
  - `scripts/*.sh`: env 로딩, agent/client 분리 실행
  - `logs/`: 실행 로그
- `samples/agent/adk/restaurant_finder/`
  - `__main__.py`, `agent_executor.py`, `agent.py`, `tools.py`
- `samples/client/flutter/restaurant_shell/`
  - `lib/main.dart`, `lib/config/app_config.dart`, `pubspec.yaml`

## 확장 이해(중급)

- `samples/agent/adk/orchestrator/`:
  - 여러 subagent를 surface 기반으로 라우팅
- `samples/agent/adk/rizzcharts/`:
  - 대시보드 시각화용 A2UI payload 생성

## 렌더러/스펙(심화)

- `renderers/`: framework별 렌더러 구현
- `specification/`: A2UI 포맷/규약
- `agent_sdks/`: SDK 관련 코드

## 설정 파일은 어디를 볼까

- Python 에이전트: 각 샘플의 `pyproject.toml`
- Flutter: `pubspec.yaml`
- Node 클라이언트: `package.json` / lockfile

> 학습 팁: lockfile은 "왜 필요한지"만 알고, 처음엔 깊게 읽지 않아도 됩니다.

