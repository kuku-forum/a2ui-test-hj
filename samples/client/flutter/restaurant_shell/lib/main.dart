// Copyright 2025 Google LLC
//
// A2UI Restaurant Finder - Flutter client. Same UX as Lit shell: chat input + A2UI surface.
// Connects to Restaurant Finder agent at http://localhost:10002 (override with AGENT_URL).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_a2ui/genui_a2ui.dart';
import 'package:logging/logging.dart';

import 'config/app_config.dart';

void main() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.message}');
  });
  runApp(const RestaurantShellApp());
}

class RestaurantShellApp extends StatefulWidget {
  /// 앱 전체 테마(다크/라이트)와 홈 스크린을 관리하는 루트 위젯.
  const RestaurantShellApp({super.key});

  @override
  State<RestaurantShellApp> createState() => _RestaurantShellAppState();
}

class _RestaurantShellAppState extends State<RestaurantShellApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2UI Shell',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      home: ChatScreen(onToggleTheme: _toggleTheme),
    );
  }
}

class ChatScreen extends StatefulWidget {
  /// 실제 학습의 중심 화면.
  ///
  /// 입력 텍스트를 에이전트로 보내고, A2UI surface(`default`)와
  /// 텍스트 메시지 히스토리를 함께 보여준다.
  const ChatScreen({super.key, this.onToggleTheme});

  final VoidCallback? onToggleTheme;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final A2uiMessageProcessor _a2uiMessageProcessor =
      A2uiMessageProcessor(catalogs: [CoreCatalogItems.asCatalog()]);
  late A2uiContentGenerator _contentGenerator;
  late GenUiConversation _conversation;
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  AppConfig _config = restaurantConfig;
  String? _agentConnectionError;

  void _clearLoading() {
    if (mounted && _loading) {
      setState(() => _loading = false);
    }
  }

  void _initClient() {
    // 학습 포인트:
    // - A2uiContentGenerator: 서버 통신 담당
    // - A2uiMessageProcessor: A2UI part를 surface 상태로 반영
    // - GenUiConversation: 사용자 메시지 <-> generator 연결
    _contentGenerator = A2uiContentGenerator(
      serverUrl: Uri.parse(_config.serverUrl),
    );
    _conversation = GenUiConversation(
      contentGenerator: _contentGenerator,
      a2uiMessageProcessor: _a2uiMessageProcessor,
    );

    _contentGenerator.textResponseStream.listen((String text) {
      if (mounted) {
        setState(() {
          _agentConnectionError = null;
          _messages.insert(0, AiTextMessage.text(text));
          _loading = false;
        });
      }
    });

    _contentGenerator.errorStream.listen((ContentGeneratorError error) {
      if (mounted) {
        final msg = error.error.toString();
        final isNetwork = msg.contains('Failed to fetch') ||
            msg.contains('ClientException') ||
            msg.contains('Connection refused');
        setState(() {
          _agentConnectionError = isNetwork ? msg : null;
          _messages.insert(
            0,
            AiTextMessage.text('Error: ${error.error}'),
          );
          _loading = false;
        });
      }
    });
  }

  void _switchConfig(AppConfig next) {
    // 앱 전환(restaurant <-> contacts) 시 이전 conversation/client를 정리하고 재초기화한다.
    _conversation.dispose();
    _contentGenerator.dispose();
    setState(() {
      _config = next;
      _messages.clear();
      _loading = false;
      _agentConnectionError = null;
    });
    _initClient();
  }

  @override
  void initState() {
    super.initState();
    _initClient();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _conversation.dispose();
    _a2uiMessageProcessor.dispose();
    _contentGenerator.dispose();
    super.dispose();
  }

  String get _loadingText {
    final lt = _config.loadingText;
    if (lt is List<dynamic>) {
      return lt.isNotEmpty ? lt.first.toString() : 'Loading...';
    }
    return lt?.toString() ?? 'Loading...';
  }

  void _handleSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textController.clear();
    setState(() {
      _messages.insert(0, UserMessage.text(trimmed));
      _loading = true;
    });
    // Agent가 텍스트 없이 A2UI만 보내는 경우를 대비한 로딩 가드.
    // (중간 이벤트가 늦을 때 spinner 무한 회전을 방지)
    Future.delayed(const Duration(seconds: 2), _clearLoading);
    _conversation.sendRequest(UserMessage.text(trimmed));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_config.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              tooltip: Theme.of(context).brightness == Brightness.dark
                  ? 'Switch to light'
                  : 'Switch to dark',
            ),
        ],
      ),
      body: Column(
        children: [
          // App switcher (Lit parity)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _appSwitcherButton('Restaurant Finder', restaurantConfig),
                const SizedBox(width: 8),
                _appSwitcherButton('Contact Manager', contactsConfig),
              ],
            ),
          ),
          // Agent unreachable hint (예: Flutter만 실행하고 agent를 안 띄운 경우)
          if (_agentConnectionError != null) _buildAgentUnreachableBanner(),
          // Hero image (Restaurant config only, Lit parity)
          if (_config.heroImage != null) _buildHero(),
          // Form: title + input (Lit order)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _config.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: _config.placeholder,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        onSubmitted: _handleSubmitted,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () =>
                          _handleSubmitted(_textController.text),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
                // Clickable example prompts (one-tap demo)
                _buildExampleChips(),
              ],
            ),
          ),
          // Scrollable content: loading or surface + messages (overflow 방지)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(_loadingText),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minHeight: 120),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLowest,
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GenUiSurface(
                              host: _a2uiMessageProcessor,
                              surfaceId: 'default',
                            ),
                          ),
                        ),
                        if (_messages.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._messages.reversed.map(_buildMessage),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _examplePrompts {
    if (_config.key == 'restaurant') {
      return [
        'Top 5 Chinese restaurants in New York.',
        'Best Italian restaurants in NYC',
        '맛집 추천해줘, Top 5 Chinese in NYC',
      ];
    }
    return ['Alex Jordan', 'Find contact: Jane'];
  }

  Widget _buildExampleChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Try:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examplePrompts
                .map(
                  (text) => ActionChip(
                    label: Text(text, style: const TextStyle(fontSize: 13)),
                    onPressed: () => _handleSubmitted(text),
                  ),
                )
                .toList(),
          ),
          if (_config.key == 'restaurant') ...[
            const SizedBox(height: 8),
            Text(
              'Then tap "Book Now" on a restaurant to reserve.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgentUnreachableBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '에이전트에 연결할 수 없습니다.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '목록/이미지를 보려면 에이전트를 먼저 실행하세요:\n'
            'demos/run-demo.sh restaurant-flutter',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = isDark
        ? (_config.heroImageDark ?? _config.heroImage)!
        : _config.heroImage!;
    // 웹에서는 web/ 경로로 로드해 asset bundle 이슈를 피한다.
    final ImageProvider imageProvider = kIsWeb
        ? NetworkImage(Uri.base.resolve(path.replaceFirst('assets/', '')).toString())
        : AssetImage(path) as ImageProvider;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: imageProvider,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
              height: 160,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.restaurant,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
        ),
      ),
    );
  }

  Widget _appSwitcherButton(String label, AppConfig config) {
    final isActive = _config.key == config.key;
    return Material(
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _switchConfig(config),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  String _messageText(ChatMessage message) {
    if (message is UserMessage) return message.text;
    if (message is AiTextMessage) return message.text;
    return message.toString();
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message is UserMessage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isUser ? Colors.blue : Colors.green,
            child: Text(
              isUser ? 'U' : 'A',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'Agent',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _messageText(message),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
