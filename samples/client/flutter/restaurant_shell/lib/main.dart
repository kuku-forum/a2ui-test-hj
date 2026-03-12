// Copyright 2025 Google LLC
//
// A2UI Restaurant Finder - Flutter client. Same UX as Lit shell: chat input + A2UI surface.
// Connects to Restaurant Finder agent at http://localhost:10002 (override with AGENT_URL).

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

  void _clearLoading() {
    if (mounted && _loading) {
      setState(() => _loading = false);
    }
  }

  void _initClient() {
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
          _messages.insert(0, AiTextMessage.text(text));
          _loading = false;
        });
      }
    });

    _contentGenerator.errorStream.listen((ContentGeneratorError error) {
      if (mounted) {
        setState(() {
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
    _conversation.dispose();
    _contentGenerator.dispose();
    setState(() {
      _config = next;
      _messages.clear();
      _loading = false;
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
    // Agent may send only A2UI (no text). Fallback: stop loading after 2s so spinner doesn't spin forever.
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
          // A2UI surface (agent-generated cards, lists)
          Expanded(
            flex: 2,
            child: ClipRect(
              child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(color: Colors.grey.shade300),
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
            ),
          ),
          const Divider(height: 1),
          // Chat messages
          Expanded(
            flex: 1,
            child: ClipRect(
              child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(_loadingText),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
                    },
                  ),
            ),
          ),
          const Divider(height: 1),
          // Input row
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _config.placeholder,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      onSubmitted: _handleSubmitted,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _handleSubmitted(_textController.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
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
