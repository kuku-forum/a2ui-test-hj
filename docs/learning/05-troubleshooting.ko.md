# 05. 트러블슈팅 가이드

초보자가 가장 자주 막히는 지점을 "증상 -> 확인 -> 조치" 순서로 정리했습니다.

## 1) API 키 오류

**증상**
- 서버 시작 직후 종료
- `OPENAI_API_KEY ... not set` 또는 유사 메시지

**확인**
- `demos/.env` 존재 여부
- `OPENAI_API_KEY` 값이 placeholder인지 확인

**조치**
```bash
cd demos
cp .env.example .env
# .env 수정
```

## 2) 포트 충돌 (10002 등)

**증상**
- `Port 10002 is in use`

**확인**
```bash
lsof -ti:10002
```

**조치**
- 기존 데모 터미널에서 `Ctrl+C`
- 필요 시 프로세스 정리 후 재실행

## 3) Flutter에서 연결 실패

**증상**
- 화면은 뜨지만 데이터가 안 옴
- `Failed to fetch`, `Connection refused` 등

**확인**
- agent가 먼저 떠 있는지 확인
- Android 에뮬레이터인지 확인

**조치**
```bash
cd demos
FLUTTER_DEVICE=android ./run-demo.sh restaurant-flutter
```

또는 `--dart-define=AGENT_URL=http://10.0.2.2:10002` 사용.

## 4) A2UI 응답이 이상함

**증상**
- 카드/폼 일부가 비거나 엉뚱한 위치에 렌더

**확인**
- `samples/agent/adk/restaurant_finder/agent_executor.py`의
  - `book_ctx` 주입
  - `surfaceId` remap
  - Flutter 안정화 처리

**조치**
- 서버 로그(`demos/logs/*.log`)에서 최종 part payload 확인

## 5) 학습 중 권장 디버깅 순서

1. `demos/README.md` 실행 명령 재확인
2. `demos/logs/*.log` 확인
3. `agent_executor.py` 분기 확인
4. 클라이언트 `main.dart` 수신/렌더 파이프라인 확인

