// Copyright 2025 Google LLC
//
// App config for Restaurant Finder and Contact Manager (Lit shell parity).
//
// AGENT_URL / CONTACTS_AGENT_URL 는 --dart-define 으로 주입 가능.
// 실물 Android 기기에서는 localhost 대신 호스트 PC 의 LAN IP 를 사용해야 한다.
//   예) flutter run --dart-define=AGENT_URL=http://192.168.1.10:10002

class AppConfig {
  /// 앱 전환(restaurant/contacts) 시 사용하는 최소 실행 설정 묶음.
  const AppConfig({
    required this.key,
    required this.title,
    required this.serverUrl,
    required this.placeholder,
    this.loadingText = 'Loading...',
    this.heroImage,
    this.heroImageDark,
  });

  final String key;
  final String title;
  final String serverUrl;
  final String placeholder;
  final dynamic loadingText; // String or List<String>
  final String? heroImage;
  final String? heroImageDark;
}

// 실물 Android 기기: --dart-define=AGENT_URL=http://<호스트IP>:10002
// 에뮬레이터:        --dart-define=AGENT_URL=http://10.0.2.2:10002
// 기본값(웹/미지정):  http://localhost:10002
const _restaurantUrl = String.fromEnvironment(
  'AGENT_URL',
  defaultValue: 'http://localhost:10002',
);

// 실물 Android 기기: --dart-define=CONTACTS_AGENT_URL=http://<호스트IP>:10003
const _contactsUrl = String.fromEnvironment(
  'CONTACTS_AGENT_URL',
  defaultValue: 'http://localhost:10003',
);

const restaurantConfig = AppConfig(
  key: 'restaurant',
  title: 'Restaurant Finder',
  serverUrl: _restaurantUrl,
  placeholder: 'Top 5 Chinese restaurants in New York.',
  loadingText: [
    'Finding the best spots for you...',
    'Checking reviews...',
    'Looking for open tables...',
    'Almost there...',
  ],
  heroImage: 'assets/hero.png',
  heroImageDark: 'assets/hero-dark.png',
);

const contactsConfig = AppConfig(
  key: 'contacts',
  title: 'Contact Manager',
  serverUrl: _contactsUrl,
  placeholder: 'Alex Jordan',
  loadingText: [
    'Searching contacts...',
    'Looking up details...',
    'Verifying information...',
    'Just a moment...',
  ],
);
