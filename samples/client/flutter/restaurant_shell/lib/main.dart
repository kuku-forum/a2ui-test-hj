// Copyright 2025 Google LLC
//
// A2UI Restaurant Finder — premium Flutter client.
// Web(Chrome) + Android 모두 지원. AGENT_URL 은 --dart-define 으로 주입.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_a2ui/genui_a2ui.dart';
import 'package:logging/logging.dart';

import 'config/app_config.dart';

// ─── 인앱 디버그 패널용 로그 엔트리 ────────────────────────────────────────────
class _LogEntry {
  final String tag; // SEND | RECV | ERROR
  final String body;
  final DateTime ts;
  _LogEntry(this.tag, this.body) : ts = DateTime.now();
}

// ─── 앱 진입점 ──────────────────────────────────────────────────────────────────
void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => debugPrint('[${r.level.name}] ${r.message}'));
  runApp(const RestaurantShellApp());
}

// ─── 색상 팔레트 (다크 우선 / OLED 최적화) ─────────────────────────────────────
const _kPrimary = Color(0xFF7B61FF); // 보라
const _kAccent = Color(0xFF4ECDC4); // 민트
const _kError = Color(0xFFFF6B6B); // 코랄 레드
const _kDarkBg = Color(0xFF0B0B17); // 매우 어두운 남색
const _kDarkSurface = Color(0xFF12122A); // 카드 배경
const _kDarkBorder = Color(0xFF252550); // 카드 테두리

// ─── 루트 위젯 ──────────────────────────────────────────────────────────────────
class RestaurantShellApp extends StatefulWidget {
  const RestaurantShellApp({super.key});

  @override
  State<RestaurantShellApp> createState() => _RestaurantShellAppState();
}

class _RestaurantShellAppState extends State<RestaurantShellApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() => setState(() {
        _themeMode =
            _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      });

  static ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kPrimary,
          brightness: b,
        ).copyWith(
          primary: _kPrimary,
          secondary: _kAccent,
          error: _kError,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2UI Restaurant',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: ChatScreen(onToggleTheme: _toggleTheme),
    );
  }
}

// ─── 메인 채팅 화면 ─────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // ── 컨트롤러 ────────────────────────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _dotAnim;

  // ── A2UI 핵심 객체 ──────────────────────────────────────────────────────────
  final A2uiMessageProcessor _processor =
      A2uiMessageProcessor(catalogs: [CoreCatalogItems.asCatalog()]);
  late A2uiContentGenerator _generator;
  late GenUiConversation _conversation;

  // ── 상태 ────────────────────────────────────────────────────────────────────
  AppConfig _config = restaurantConfig;
  final List<ChatMessage> _messages = [];
  final List<_LogEntry> _logs = [];
  bool _loading = false;
  String? _netError;

  // ─── 생명주기 ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initClient();
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _conversation.dispose();
    _processor.dispose();
    _generator.dispose();
    super.dispose();
  }

  void _initClient() {
    _generator = A2uiContentGenerator(serverUrl: Uri.parse(_config.serverUrl));
    _conversation = GenUiConversation(
      contentGenerator: _generator,
      a2uiMessageProcessor: _processor,
    );

    // 텍스트 응답 수신
    _generator.textResponseStream.listen((text) {
      if (!mounted) return;
      setState(() {
        _netError = null;
        _messages.insert(0, AiTextMessage.text(text));
        _logs.insert(0, _LogEntry('RECV', text));
        _loading = false;
      });
    });

    // 에러 수신
    _generator.errorStream.listen((err) {
      if (!mounted) return;
      final msg = err.error.toString();
      setState(() {
        _netError = msg.contains('fetch') ||
                msg.contains('ClientException') ||
                msg.contains('refused')
            ? msg
            : null;
        _messages.insert(0, AiTextMessage.text('Error: ${err.error}'));
        _logs.insert(0, _LogEntry('ERROR', msg));
        _loading = false;
      });
    });
  }

  void _switchConfig(AppConfig next) {
    _conversation.dispose();
    _generator.dispose();
    setState(() {
      _config = next;
      _messages.clear();
      _loading = false;
      _netError = null;
    });
    _initClient();
  }

  void _submit(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    setState(() {
      _messages.insert(0, UserMessage.text(t));
      _logs.insert(0, _LogEntry('SEND', t));
      _loading = true;
    });
    // 텍스트 없이 A2UI만 오는 경우 spinner 무한 회전 방지
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
    _conversation.sendRequest(UserMessage.text(t));
  }

  // ─── 빌드 ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? _kDarkBg : cs.surface,
      body: Column(
        children: [
          _AppBar(
            title: _config.title,
            isDark: isDark,
            cs: cs,
            logCount: _logs.length,
            onDebug: _showDebugPanel,
            onToggleTheme: widget.onToggleTheme,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 앱 스위처
                  _AppSwitcher(
                    config: _config,
                    isDark: isDark,
                    cs: cs,
                    onSwitch: _switchConfig,
                  ),
                  const SizedBox(height: 10),
                  // 네트워크 에러 배너
                  if (_netError != null) _ErrorBanner(cs: cs),
                  // 히어로 이미지
                  if (_config.heroImage != null) ...[
                    _HeroImage(config: _config, isDark: isDark),
                    const SizedBox(height: 10),
                  ],
                  // A2UI 서피스 (항상 표시 — loading 중에도 숨기지 않음)
                  _SurfaceCard(
                      processor: _processor, isDark: isDark, cs: cs),
                  // 로딩 도트 인디케이터
                  if (_loading) _LoadingDots(anim: _dotAnim, cs: cs),
                  // 채팅 메시지 기록
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ..._messages.reversed.map((m) => _MessageBubble(
                          message: m,
                          isDark: isDark,
                          cs: cs,
                        )),
                  ],
                  const SizedBox(height: 100), // 입력창 공간 확보
                ],
              ),
            ),
          ),
        ],
      ),
      // 입력창: 화면 하단 고정
      bottomNavigationBar: _InputBar(
        config: _config,
        controller: _textCtrl,
        isDark: isDark,
        cs: cs,
        onSubmit: _submit,
      ),
    );
  }

  // ─── 디버그 패널 (클라이언트 SEND/RECV/ERROR) ────────────────────────────
  void _showDebugPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.95,
          builder: (_, sc) => Column(
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A5A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 패널 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        color: _kAccent, size: 17),
                    const SizedBox(width: 7),
                    const Text(
                      'Client Logs',
                      style: TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(count: _logs.length, color: _kPrimary),
                    const Spacer(),
                    // 서버 로그 힌트
                    const Text(
                      'Server: :10002/debug',
                      style: TextStyle(
                          color: Color(0xFF505070),
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        setState(() => _logs.clear());
                        Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF505070)),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1E1E3A), height: 1),
              // 로그 목록
              Expanded(
                child: _logs.isEmpty
                    ? const _EmptyLogs()
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.all(14),
                        itemCount: _logs.length,
                        itemBuilder: (_, i) => _LogCard(entry: _logs[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 분리된 위젯들 (가독성 + 재사용성)
// ═══════════════════════════════════════════════════════════════════════════════

/// 커스텀 앱바 (그라디언트 + 디버그 버튼 + 테마 토글)
class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.title,
    required this.isDark,
    required this.cs,
    required this.logCount,
    required this.onDebug,
    this.onToggleTheme,
  });

  final String title;
  final bool isDark;
  final ColorScheme cs;
  final int logCount;
  final VoidCallback onDebug;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1035), _kDarkBg]
              : [cs.primaryContainer, cs.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withOpacity(isDark ? 0.2 : 0.1),
              blurRadius: 14,
              offset: const Offset(0, 3))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // 앱 로고
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : cs.onSurface,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 디버그 버튼 (클라이언트 로그 패널)
                Stack(
                  alignment: Alignment.topRight,
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: onDebug,
                      icon: Icon(Icons.bug_report_outlined,
                          color: isDark
                              ? _kPrimary.withOpacity(0.85)
                              : cs.primary,
                          size: 22),
                      tooltip: 'Client logs',
                    ),
                    if (logCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: _kAccent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
                // 테마 토글
                if (onToggleTheme != null)
                  IconButton(
                    onPressed: onToggleTheme,
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: isDark ? const Color(0xFFFFD166) : cs.onSurface,
                      size: 22,
                    ),
                    tooltip: isDark ? 'Light mode' : 'Dark mode',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 앱 스위처 (Restaurant ↔ Contacts)
class _AppSwitcher extends StatelessWidget {
  const _AppSwitcher({
    required this.config,
    required this.isDark,
    required this.cs,
    required this.onSwitch,
  });

  final AppConfig config;
  final bool isDark;
  final ColorScheme cs;
  final void Function(AppConfig) onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141430) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _switchBtn(context, '🍽️  Restaurant', restaurantConfig),
          const SizedBox(width: 4),
          _switchBtn(context, '👥  Contacts', contactsConfig),
        ],
      ),
    );
  }

  Widget _switchBtn(BuildContext ctx, String label, AppConfig cfg) {
    final isActive = config.key == cfg.key;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSwitch(cfg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [_kPrimary, _kAccent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
              color: isActive
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFF6060A0)
                      : cs.onSurface.withOpacity(0.55)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 히어로 이미지 (그라디언트 오버레이 포함)
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.config, required this.isDark});
  final AppConfig config;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final path =
        isDark ? (config.heroImageDark ?? config.heroImage)! : config.heroImage!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image(
            image: AssetImage(path),
            height: 148,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 148,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A1060), Color(0xFF0A2040)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child:
                  const Icon(Icons.restaurant_menu, size: 52, color: Colors.white30),
            ),
          ),
          // 아래쪽 어두운 그라디언트 오버레이
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xDD000000)],
                  begin: Alignment(0, 0),
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // 오버레이 텍스트
          Positioned(
            bottom: 12,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        config.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Text(
                        'Powered by A2UI · Google ADK',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Live Demo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A2UI 서피스 카드 (항상 표시)
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard(
      {required this.processor, required this.isDark, required this.cs});
  final A2uiMessageProcessor processor;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: isDark ? _kDarkSurface : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _kDarkBorder : cs.outlineVariant),
        boxShadow: isDark
            ? [
                BoxShadow(
                    color: _kPrimary.withOpacity(0.06),
                    blurRadius: 20,
                    spreadRadius: 2)
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GenUiSurface(host: processor, surfaceId: 'default'),
      ),
    );
  }
}

/// 로딩 도트 애니메이션
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.anim, required this.cs});
  final AnimationController anim;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final phase = ((anim.value * 3 - i) % 3) / 3;
              final scale = 0.5 + 0.5 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 9 * scale,
                height: 9 * scale,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.4 + 0.6 * scale),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// 메시지 버블
class _MessageBubble extends StatelessWidget {
  const _MessageBubble(
      {required this.message, required this.isDark, required this.cs});
  final ChatMessage message;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isUser = message is UserMessage;
    final text = isUser
        ? (message as UserMessage).text
        : (message as AiTextMessage).text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // AI 아바타
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_kPrimary, _kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [_kPrimary, Color(0xFF5A45CC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? null
                    : (isDark ? const Color(0xFF1A1A35) : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? _kAccent.withOpacity(0.12)
                            : cs.outlineVariant,
                        width: 0.8),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? const Color(0xFFD0D0F0) : cs.onSurface),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          // 사용자 아바타
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E40) : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                    color: _kPrimary.withOpacity(0.4), width: 0.8),
              ),
              child: Icon(Icons.person_outline,
                  color: cs.primary, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

/// 하단 고정 입력바 (예시 칩 + 텍스트필드 + 전송 버튼)
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.config,
    required this.controller,
    required this.isDark,
    required this.cs,
    required this.onSubmit,
  });

  final AppConfig config;
  final TextEditingController controller;
  final bool isDark;
  final ColorScheme cs;
  final void Function(String) onSubmit;

  List<String> get _prompts => config.key == 'restaurant'
      ? ['Top 5 Chinese in NYC', 'Best Italian NYC', '맛집 추천 Top5']
      : ['Alex Jordan', 'Find: Jane'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      decoration: BoxDecoration(
        color: isDark ? _kDarkBg : cs.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? _kDarkBorder : cs.outlineVariant,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 예시 칩
          Wrap(
            spacing: 7,
            runSpacing: 5,
            children: _prompts
                .map((t) => GestureDetector(
                      onTap: () => onSubmit(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? _kPrimary.withOpacity(0.1)
                              : cs.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _kPrimary.withOpacity(isDark ? 0.3 : 0.35),
                              width: 0.8),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? _kPrimary.withOpacity(0.9)
                                : cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 9),
          // 입력 필드 + 전송 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? _kDarkSurface
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: isDark
                            ? _kPrimary.withOpacity(0.25)
                            : cs.outlineVariant,
                        width: 1),
                  ),
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFFE0E0F0)
                            : cs.onSurface,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: config.placeholder ?? 'Ask about restaurants…',
                      hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF505075)
                              : cs.onSurface.withOpacity(0.4),
                          fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: onSubmit,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 전송 버튼 (그라디언트 원)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kPrimary, _kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x557B61FF),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ],
                ),
                child: IconButton(
                  onPressed: () => onSubmit(controller.text),
                  icon: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 네트워크 에러 배너
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _kError.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kError.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: _kError, size: 17),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('에이전트에 연결할 수 없습니다',
                    style: TextStyle(
                        color: _kError,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text('demos/run-demo.sh restaurant-flutter',
                    style: TextStyle(
                        color: _kError,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 배지 (숫자 표시)
class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 로그 카드 (디버그 패널용)
class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});
  final _LogEntry entry;

  static const _tagColors = {
    'SEND': _kPrimary,
    'RECV': _kAccent,
    'ERROR': _kError,
  };

  @override
  Widget build(BuildContext context) {
    final color = _tagColors[entry.tag] ?? Colors.white54;
    final ts =
        '${entry.ts.hour.toString().padLeft(2, '0')}:${entry.ts.minute.toString().padLeft(2, '0')}:${entry.ts.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.22), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  entry.tag,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
              ),
              const SizedBox(width: 8),
              Text(ts,
                  style: const TextStyle(
                      color: Color(0xFF505075), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.body,
            style: const TextStyle(
              color: Color(0xFFB0B0D0),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 빈 로그 상태
class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF252545), size: 44),
          SizedBox(height: 12),
          Text('No logs yet.',
              style: TextStyle(color: Color(0xFF505075), fontSize: 14)),
          SizedBox(height: 4),
          Text('Send a message to capture SEND / RECV / ERROR.',
              style: TextStyle(color: Color(0xFF3A3A5A), fontSize: 12)),
        ],
      ),
    );
  }
}
