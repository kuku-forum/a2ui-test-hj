# 01. 빠른 시작 (Quick Start)

## 목표

5~10분 안에 데모를 실행해서 "요청이 실제로 왕복한다"는 감각을 잡습니다.

## 1) 환경 변수 준비

```bash
cd demos
cp .env.example .env
```

`.env`에 최소한 아래를 설정합니다.

```bash
OPENAI_API_KEY=sk-...
GPT_MODEL=gpt-5.4
```

> 참고: `demos/scripts/load-env.sh`가 `GPT_MODEL`을 `LITELLM_MODEL=openai/<모델>`로 자동 매핑합니다.

## 2) 데모 실행 (권장 1개 선택)

### A. Lit 데모 (가볍고 빠름)

```bash
cd demos
./run-demo.sh restaurant-lit
```

- Agent: `http://localhost:10002`
- Client: `http://localhost:5173`

### B. Flutter 데모 (앱형 UI 확인)

```bash
cd demos
./run-demo.sh restaurant-flutter
```

Android 에뮬레이터 사용 시:

```bash
cd demos
FLUTTER_DEVICE=android ./run-demo.sh restaurant-flutter
```

## 3) 성공 기준

- [ ] 클라이언트에서 질문 입력 가능
- [ ] 레스토랑 카드/폼이 화면에 보임
- [ ] "Book Now" 또는 비슷한 버튼 반응 확인

## 4) 바로 다음 문서

실행이 되면 `02-end-to-end-flow.ko.md`로 이동해  
"내 입력이 코드 어디를 지나서 화면으로 돌아오는지"를 추적합니다.

