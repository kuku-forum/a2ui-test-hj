# A2UI Shell – Flutter client (Lit parity)

Restaurant Finder / Contact Manager 앱 전환, 다크·라이트 테마, Lit 셸과 동일한 레이아웃(폼 + A2UI 서피스). **Restaurant Finder**: 검색 후 "Book Now" → 예약 폼 → "Submit Reservation"으로 예약 플로우 지원.

## 기능

- **앱 전환**: Restaurant Finder (10002), Contact Manager (10003)
- **테마 토글**: 상단 우측 아이콘으로 다크/라이트 전환
- **히어로 이미지**: Restaurant 선택 시 표시 (에셋 있으면; 없으면 플레이스홀더)

## 요구사항

- Flutter SDK (3.35.7+)
- Restaurant Finder 에이전트: `http://localhost:10002`
- Contact Manager 에이전트: `http://localhost:10003` (Contact Manager 사용 시)

## 실행 (목록·이미지 보려면 에이전트 필수)

**레스토랑 목록과 카드 이미지**는 에이전트가 `http://localhost:10002`에서 실행 중일 때만 로드됩니다. `flutter run -d chrome`만 하면 에이전트에 연결되지 않아 "Failed to fetch"가 나고 이미지가 안 나옵니다. **반드시 아래처럼 에이전트와 함께 실행하세요.**

## 실행

```bash
# 1) 에이전트 실행 (다른 터미널에서)
cd demos && ./run-demo.sh restaurant-lit   # 에이전트만 쓰려면 agent만 띄우거나
# 또는: cd samples/agent/adk/restaurant_finder && uv run . --port 10002

# 2) Flutter 클라이언트
cd samples/client/flutter/restaurant_shell
flutter pub get
flutter run -d chrome    # 웹
# 또는: flutter run -d ios  /  flutter run -d android
```

**한 번에 실행 (권장)**: `demos` 폴더에서 `./run-demo.sh restaurant-flutter` (에이전트 + Flutter 클라이언트를 한 번에 실행. 이렇게 해야 목록·카드 이미지가 정상 로드됨).

**최초 1회**: `flutter run -d chrome` 이 실패하면 플랫폼 폴더 생성 후 다시 시도하세요.
```bash
cd samples/client/flutter/restaurant_shell
flutter create . --project-name=restaurant_shell --platforms=web,android,ios
# (pubspec.yaml과 lib/main.dart가 덮어쓰이면 git checkout으로 복구)
flutter pub get && flutter run -d chrome
```

## 플랫폼

- **Web**: `flutter run -d chrome`
- **iOS**: `flutter run -d ios`
- **Android**: `flutter run -d android`

에이전트 URL 변경: `flutter run -d chrome --dart-define=AGENT_URL=http://10.0.2.2:10002` (예: Android 에뮬레이터)

## 히어로 이미지

Restaurant Finder 상단 히어로는 `assets/hero.png`, `assets/hero-dark.png` (Lit 셸 `public/` 에서 복사해 둔 이미지)를 사용합니다. 레스토랑 목록/카드 이미지는 에이전트가 `http://localhost:10002/static/` 에서 제공하므로, 데모 시 에이전트를 먼저 실행해야 이미지가 로드됩니다.
