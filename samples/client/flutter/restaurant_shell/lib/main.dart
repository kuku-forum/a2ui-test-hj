// Copyright 2025 Google LLC
//
// A2UI Restaurant Finder — Flutter client.
// Web + Android 지원. AGENT_URL 은 --dart-define 으로 주입.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_a2ui/genui_a2ui.dart';
import 'package:logging/logging.dart';

import 'config/app_config.dart';

// ─── 디버그 로그 엔트리 ─────────────────────────────────────────────────────────
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

// ─── 색상 팔레트 ──────────────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF7B61FF);
const _kAccent     = Color(0xFF4ECDC4);
const _kError      = Color(0xFFFF6B6B);
const _kSuccess    = Color(0xFF4ADE80);
const _kDarkBg     = Color(0xFF0B0B17);
const _kDarkSurface = Color(0xFF12122A);
const _kDarkBorder  = Color(0xFF252550);

// ─── 루트 위젯 ──────────────────────────────────────────────────────────────────
class RestaurantShellApp extends StatefulWidget {
  const RestaurantShellApp({super.key});
  @override
  State<RestaurantShellApp> createState() => _RestaurantShellAppState();
}

class _RestaurantShellAppState extends State<RestaurantShellApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  void _toggleTheme() => setState(() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  });

  static ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _kPrimary,
      brightness: b,
    ).copyWith(primary: _kPrimary, secondary: _kAccent, error: _kError),
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

// ─── 메인 화면 ──────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // ── 컨트롤러 ──────────────────────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  late AnimationController _dotAnim;
  late AnimationController _fadeAnim;

  // ── A2UI 핵심 객체 ────────────────────────────────────────────────────────
  final A2uiMessageProcessor _processor =
      A2uiMessageProcessor(catalogs: [CoreCatalogItems.asCatalog()]);
  late A2uiContentGenerator _generator;
  late GenUiConversation _conversation;

  // ── 상태 ──────────────────────────────────────────────────────────────────
  AppConfig _config = restaurantConfig;
  final List<_LogEntry> _logs = [];
  bool _loading = false;
  bool _hasReceivedResponse = false; // 첫 응답 후 surface 전체화면 모드
  int _responseVersion = 0;          // AnimatedSwitcher 트리거용
  String? _netError;
  String? _lastStatusText;           // 에이전트 상태 텍스트 (표시용)

  // ── 생명주기 ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();
    _fadeAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _initClient();
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    _fadeAnim.dispose();
    _textCtrl.dispose();
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

    _generator.textResponseStream.listen((text) {
      if (!mounted) return;
      setState(() {
        _netError = null;
        _loading = false;
        _hasReceivedResponse = true;
        _responseVersion++;
        _lastStatusText = text.isNotEmpty ? text : null;
        _logs.insert(0, _LogEntry('RECV', text));
      });
    });

    _generator.errorStream.listen((err) {
      if (!mounted) return;
      final msg = err.error.toString();
      setState(() {
        _netError = (msg.contains('fetch') ||
                msg.contains('ClientException') ||
                msg.contains('refused') ||
                msg.contains('Connection') ||
                msg.contains('SocketException'))
            ? msg
            : null;
        _loading = false;
        _hasReceivedResponse = true;
        _responseVersion++;
        _logs.insert(0, _LogEntry('ERROR', msg));
      });
    });
  }

  void _switchConfig(AppConfig next) {
    _conversation.dispose();
    _generator.dispose();
    setState(() {
      _config = next;
      _logs.clear();
      _loading = false;
      _hasReceivedResponse = false;
      _responseVersion = 0;
      _netError = null;
      _lastStatusText = null;
    });
    _initClient();
  }

  void _reset() {
    _conversation.dispose();
    _generator.dispose();
    setState(() {
      _logs.clear();
      _loading = false;
      _hasReceivedResponse = false;
      _responseVersion = 0;
      _netError = null;
      _lastStatusText = null;
    });
    _initClient();
  }

  void _submit(String text) {
    final t = text.trim();
    if (t.isEmpty || _loading) return;
    _textCtrl.clear();
    setState(() {
      _loading = true;
      _netError = null;
      _logs.insert(0, _LogEntry('SEND', t));
    });
    // A2UI-only 응답(텍스트 없음) 시 spinner 무한 방지
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _hasReceivedResponse = true;
          _responseVersion++;
        });
      }
    });
    _conversation.sendRequest(UserMessage.text(t));
  }

  // ─── 빌드 ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? _kDarkBg : cs.surface,
      body: Column(
        children: [
          // ── 앱바 ────────────────────────────────────────────────────────
          _AppBar(
            title: _config.title,
            isDark: isDark,
            cs: cs,
            logCount: _logs.length,
            showReset: _hasReceivedResponse,
            onDebug: _showDebugPanel,
            onToggleTheme: widget.onToggleTheme,
            onReset: _reset,
          ),
          // ── 앱 스위처 ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: _AppSwitcher(
              config: _config,
              isDark: isDark,
              cs: cs,
              onSwitch: _switchConfig,
            ),
          ),
          // ── 네트워크 에러 배너 ────────────────────────────────────────────
          if (_netError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: _ErrorBanner(cs: cs, message: _netError),
            ),
          // ── 메인 컨텐츠 ──────────────────────────────────────────────────
          Expanded(
            child: _hasReceivedResponse
                ? _buildSurfaceView(isDark, cs)
                : _buildWelcomeView(isDark, cs),
          ),
        ],
      ),
      bottomNavigationBar: _InputBar(
        config: _config,
        controller: _textCtrl,
        isDark: isDark,
        cs: cs,
        loading: _loading,
        onSubmit: _submit,
      ),
    );
  }

  // 응답 전: 히어로 + 안내 화면
  Widget _buildWelcomeView(bool isDark, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_config.heroImage != null) ...[
            _HeroImage(config: _config, isDark: isDark),
            const SizedBox(height: 18),
          ],
          // 안내 텍스트
          Text(
            _config.key == 'restaurant'
                ? '맛집을 찾아드립니다 🍽️'
                : '연락처를 찾아드립니다 👥',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _config.key == 'restaurant'
                ? '음식 종류와 지역을 입력하면\n맛집 목록 · 상세 정보 · 예약까지 한번에!'
                : '이름이나 키워드로 연락처를 검색하세요.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF8080A0) : cs.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // 예시 검색 칩들
          if (_config.key == 'restaurant') ...[
            _SuggestionGrid(isDark: isDark, cs: cs, onTap: _submit),
          ],
          if (_loading) ...[
            const SizedBox(height: 24),
            _LoadingDots(anim: _dotAnim, cs: cs, message: '검색 중...'),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // 응답 후: surface 전체 화면
  Widget _buildSurfaceView(bool isDark, ColorScheme cs) {
    return Stack(
      children: [
        // Surface 카드가 전체 공간 차지
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            child: _FullSurfaceCard(
              key: ValueKey(_responseVersion),
              processor: _processor,
              isDark: isDark,
              cs: cs,
            ),
          ),
        ),
        // 로딩 오버레이
        if (_loading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? _kDarkBg : Colors.white).withOpacity(0.7),
                borderRadius: BorderRadius.circular(0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoadingDots(anim: _dotAnim, cs: cs, message: '처리 중...'),
                ],
              ),
            ),
          ),
        // 상태 텍스트 (하단 작은 배너)
        if (_lastStatusText != null && !_loading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StatusBanner(text: _lastStatusText!, isDark: isDark, cs: cs),
          ),
      ],
    );
  }

  // ─── 디버그 패널 ───────────────────────────────────────────────────────────
  void _showDebugPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (_, sc) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A5A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: _kAccent, size: 17),
                  const SizedBox(width: 7),
                  const Text('Client Logs',
                      style: TextStyle(color: _kAccent, fontWeight: FontWeight.bold,
                          fontSize: 14, letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  _Badge(count: _logs.length, color: _kPrimary),
                  const Spacer(),
                  const Text('Server: :10002/debug',
                      style: TextStyle(color: Color(0xFF505070), fontSize: 10,
                          fontFamily: 'monospace')),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () { setState(() => _logs.clear()); Navigator.pop(ctx); },
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF505070)),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E1E3A), height: 1),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 위젯 컴포넌트
// ═══════════════════════════════════════════════════════════════════════════════

/// 커스텀 앱바
class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.title, required this.isDark, required this.cs,
    required this.logCount, required this.showReset,
    required this.onDebug, this.onToggleTheme, required this.onReset,
  });

  final String title;
  final bool isDark, showReset;
  final ColorScheme cs;
  final int logCount;
  final VoidCallback onDebug, onReset;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1035), _kDarkBg]
              : [cs.primaryContainer, cs.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(
          color: _kPrimary.withOpacity(isDark ? 0.2 : 0.1),
          blurRadius: 14, offset: const Offset(0, 3),
        )],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // 로고
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kAccent],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : cs.onSurface,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 새 검색 버튼 (응답 후에만 표시)
                if (showReset)
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('새 검색', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? _kAccent : cs.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                // 디버그 버튼
                Stack(
                  alignment: Alignment.topRight,
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: onDebug,
                      icon: Icon(Icons.bug_report_outlined,
                          color: isDark ? _kPrimary.withOpacity(0.85) : cs.primary,
                          size: 22),
                      tooltip: 'Client logs',
                    ),
                    if (logCount > 0)
                      Positioned(
                        right: 6, top: 6,
                        child: Container(
                          width: 8, height: 8,
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
    required this.config, required this.isDark,
    required this.cs, required this.onSwitch,
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
          _btn(context, '🍽️  Restaurant', restaurantConfig),
          const SizedBox(width: 4),
          _btn(context, '👥  Contacts', contactsConfig),
        ],
      ),
    );
  }

  Widget _btn(BuildContext ctx, String label, AppConfig cfg) {
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
                    begin: Alignment.centerLeft, end: Alignment.centerRight)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
              color: isActive
                  ? Colors.white
                  : (isDark ? const Color(0xFF6060A0) : cs.onSurface.withOpacity(0.55)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 히어로 이미지
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.config, required this.isDark});
  final AppConfig config;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final path = isDark
        ? (config.heroImageDark ?? config.heroImage)!
        : config.heroImage!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Image(
            image: AssetImage(path),
            height: 180, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A1060), Color(0xFF0A2040)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.restaurant_menu, size: 60, color: Colors.white24),
            ),
          ),
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xDD000000)],
                  begin: Alignment(0, 0.2), end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16, left: 18, right: 18,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(config.title,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                      const Text('Powered by A2UI · Google ADK',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Live Demo',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색 제안 그리드
class _SuggestionGrid extends StatelessWidget {
  const _SuggestionGrid({required this.isDark, required this.cs, required this.onTap});
  final bool isDark;
  final ColorScheme cs;
  final void Function(String) onTap;

  static const _suggestions = [
    ('🍜', 'NYC 중식 Top 5', 'Top 5 Chinese restaurants in New York'),
    ('🍝', 'NYC 이탈리안', 'Top 5 Italian restaurants in New York'),
    ('🍣', 'NYC 스시 맛집', 'Top 5 Sushi restaurants in New York'),
    ('🥩', 'NYC 스테이크', 'Top 5 Steak restaurants in New York'),
    ('🍕', 'NYC 피자 Best', 'Top 5 Pizza places in New York'),
    ('🥗','건강식 맛집', 'Top 5 Healthy restaurants in New York'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('인기 검색어',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8080A0) : cs.onSurface.withOpacity(0.6),
            )),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3.0,
          children: _suggestions.map((s) {
            return GestureDetector(
              onTap: () => onTap(s.$3),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? _kDarkSurface : cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? _kDarkBorder : cs.outlineVariant,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(s.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.$2,
                        style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFD0D0F0) : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Surface 전체화면 카드
class _FullSurfaceCard extends StatelessWidget {
  const _FullSurfaceCard({super.key, required this.processor,
      required this.isDark, required this.cs});
  final A2uiMessageProcessor processor;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      decoration: BoxDecoration(
        color: isDark ? _kDarkSurface : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? _kDarkBorder : cs.outlineVariant,
          width: 0.8,
        ),
        boxShadow: isDark
            ? [BoxShadow(color: _kPrimary.withOpacity(0.07),
                blurRadius: 24, spreadRadius: 2)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GenUiSurface(host: processor, surfaceId: 'default'),
      ),
    );
  }
}

/// 로딩 도트 애니메이션
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.anim, required this.cs, this.message});
  final AnimationController anim;
  final ColorScheme cs;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final phase = ((anim.value * 3 - i) % 3) / 3;
                final scale = 0.5 + 0.5 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 10 * scale, height: 10 * scale,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.4 + 0.6 * scale),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.5),
              )),
          ],
        ],
      ),
    );
  }
}

/// 하단 상태 텍스트 배너
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, required this.isDark, required this.cs});
  final String text;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F0F22).withOpacity(0.95)
            : cs.surfaceContainerHighest.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? _kDarkBorder : cs.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined,
              color: isDark ? _kAccent : cs.primary, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9090C0) : cs.onSurface.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 입력바
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.config, required this.controller,
    required this.isDark, required this.cs,
    required this.loading, required this.onSubmit,
  });

  final AppConfig config;
  final TextEditingController controller;
  final bool isDark, loading;
  final ColorScheme cs;
  final void Function(String) onSubmit;

  List<String> get _quickPrompts => config.key == 'restaurant'
      ? ['NYC 중식 Top 5', '이탈리안 Top 5', '스시 맛집']
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
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 빠른 검색 칩
          Wrap(
            spacing: 7, runSpacing: 5,
            children: _quickPrompts.map((t) => GestureDetector(
              onTap: loading ? null : () => onSubmit(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? _kPrimary.withOpacity(loading ? 0.05 : 0.1)
                      : cs.primaryContainer.withOpacity(loading ? 0.3 : 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _kPrimary.withOpacity(isDark ? (loading ? 0.15 : 0.3) : 0.35),
                      width: 0.8),
                ),
                child: Text(t,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? _kPrimary.withOpacity(loading ? 0.4 : 0.9)
                        : cs.primary.withOpacity(loading ? 0.4 : 1.0),
                    fontWeight: FontWeight.w500,
                  )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? _kDarkSurface : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: isDark
                            ? _kPrimary.withOpacity(0.25)
                            : cs.outlineVariant,
                        width: 1),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !loading,
                    style: TextStyle(
                        color: isDark ? const Color(0xFFE0E0F0) : cs.onSurface,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: loading
                          ? '처리 중...'
                          : (config.placeholder ?? 'Ask about restaurants…'),
                      hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF505075)
                              : cs.onSurface.withOpacity(0.4),
                          fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: loading ? null : onSubmit,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 전송 버튼
              Container(
                decoration: BoxDecoration(
                  gradient: loading
                      ? null
                      : const LinearGradient(
                          colors: [_kPrimary, _kAccent],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                  color: loading ? const Color(0xFF303050) : null,
                  shape: BoxShape.circle,
                  boxShadow: loading
                      ? null
                      : const [BoxShadow(
                          color: Color(0x557B61FF),
                          blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: IconButton(
                  onPressed: loading ? null : () => onSubmit(controller.text),
                  icon: Icon(
                    loading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
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
  const _ErrorBanner({required this.cs, this.message});
  final ColorScheme cs;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _kError.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kError.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: _kError, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('에이전트에 연결할 수 없습니다',
                    style: TextStyle(color: _kError, fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (message != null)
                  Text(message!,
                      style: const TextStyle(color: _kError, fontSize: 10,
                          fontFamily: 'monospace'),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 배지
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
      child: Text('$count',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

/// 로그 카드
class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});
  final _LogEntry entry;

  static const _tagColors = {
    'SEND': _kPrimary, 'RECV': _kAccent, 'ERROR': _kError,
  };

  @override
  Widget build(BuildContext context) {
    final color = _tagColors[entry.tag] ?? Colors.white54;
    final ts = '${entry.ts.hour.toString().padLeft(2,'0')}:'
        '${entry.ts.minute.toString().padLeft(2,'0')}:'
        '${entry.ts.second.toString().padLeft(2,'0')}';

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
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(entry.tag,
                  style: TextStyle(color: color, fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
            const SizedBox(width: 8),
            Text(ts, style: const TextStyle(color: Color(0xFF505075), fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Text(entry.body,
            style: const TextStyle(color: Color(0xFFB0B0D0), fontSize: 12,
                fontFamily: 'monospace'),
            maxLines: 10, overflow: TextOverflow.ellipsis),
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
