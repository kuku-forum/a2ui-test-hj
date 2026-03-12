// Copyright 2025 Google LLC
//
// App config for Restaurant Finder and Contact Manager (Lit shell parity).

class AppConfig {
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

const restaurantConfig = AppConfig(
  key: 'restaurant',
  title: 'Restaurant Finder',
  serverUrl: 'http://localhost:10002',
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
  serverUrl: 'http://localhost:10003',
  placeholder: 'Alex Jordan',
  loadingText: [
    'Searching contacts...',
    'Looking up details...',
    'Verifying information...',
    'Just a moment...',
  ],
);
