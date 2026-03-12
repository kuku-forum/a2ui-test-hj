# A2UI 학습 허브 (한국어)

이 문서는 **레포를 처음 보는 학습자**를 위한 시작점입니다.  
핵심 목표는 "데모를 돌리면서 코드 흐름을 이해"하는 것입니다.

## 추천 학습 루트

- **10분 루트**: `01-quick-start.ko.md`만 따라 실행 성공 경험 만들기
- **30분 루트**: `01` + `02-end-to-end-flow.ko.md`로 전체 데이터 흐름 이해
- **반나절 루트**: `03-agent-internals.ko.md` + `04-client-rendering.ko.md` + `05-troubleshooting.ko.md`

## 문서 순서

1. `docs/learning/01-quick-start.ko.md`
2. `docs/learning/02-end-to-end-flow.ko.md`
3. `docs/learning/03-agent-internals.ko.md`
4. `docs/learning/04-client-rendering.ko.md`
5. `docs/learning/05-troubleshooting.ko.md`
6. `docs/learning/06-repo-map.ko.md`

## 용어 미리보기

- **A2A**: Agent-to-Agent 통신 프로토콜
- **A2UI**: 에이전트가 보내는 선언형 UI 메시지 포맷
- **surface**: 클라이언트에서 렌더되는 UI 영역 단위
- **userAction**: 버튼 클릭/폼 제출 같은 클라이언트 이벤트 payload

## 첫 실행 추천

가장 먼저 아래 둘 중 하나를 실행하세요.

```bash
cd demos
./run-demo.sh restaurant-lit
```

또는

```bash
cd demos
./run-demo.sh restaurant-flutter
```

