import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../agent/agent_orchestrator.dart';
import '../agent/chat_persistence_service.dart';
import '../agent/models/agent_message.dart';
import 'model_download_screen.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <AgentMessage>[];

  bool _isLoading = false;
  bool _isReady = false;
  String _statusText = '';
  String? _historyFilePath;
  String? _modelError;

  // ── Suggestion chips shown on the empty state ──
  static const _suggestions = [
    'How much did I spend this month?',
    'What\'s my budget status?',
    'Show uncategorized transactions',
    'Find recurring payments',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAgent());
  }

  Future<void> _initAgent() async {
    final orchestrator = AgentOrchestrator.instance;

    if (orchestrator.modelStatus == ModelStatus.needsDownload) {
      await _promptDownload();
      return;
    }

    // Trigger a rebuild so the chip switches from "Checking…" to "Loading…"
    // as soon as _init() progresses past the isLoaded check.
    if (mounted) setState(() {});

    try {
      await orchestrator.ready;
    } catch (_) {}

    if (!mounted) return;

    if (orchestrator.modelStatus == ModelStatus.needsDownload) {
      await _promptDownload();
      return;
    }

    if (orchestrator.isReady) {
      setState(() => _isReady = true);
      await ChatPersistenceService.startSession();
      final path = await ChatPersistenceService.getFilePath();
      if (mounted) setState(() => _historyFilePath = path);
    } else {
      // Init failed — surface the error so the user can retry.
      setState(() => _modelError = orchestrator.initError ?? 'Model failed to load.');
    }
  }


  Future<void> _promptDownload() async {
    if (!mounted) return;
    final downloaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
    );
    if (downloaded == true && mounted) {
      setState(() => _isReady = AgentOrchestrator.instance.isReady);
      if (_isReady) {
        await ChatPersistenceService.startSession();
        final path = await ChatPersistenceService.getFilePath();
        if (mounted) setState(() => _historyFilePath = path);
      }
    }
  }

  @override
  void dispose() {
    ChatPersistenceService.endSession();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Message sending ───────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _controller.clear();

    // Add user bubble + placeholder assistant bubble
    setState(() {
      _messages.add(AgentMessage(role: 'user', content: trimmed));
      _messages.add(AgentMessage(role: 'assistant', content: ''));
      _isLoading = true;
      _statusText = '';
    });
    _scrollToBottom();

    await ChatPersistenceService.appendMessage(
      role: 'user',
      content: trimmed,
    );

    String accumulated = '';

    final response = await AgentOrchestrator.instance.handle(
      trimmed,
      onToken: (token) {
        accumulated += token;
        if (mounted) {
          setState(() {
            _messages[_messages.length - 1] =
                AgentMessage(role: 'assistant', content: accumulated);
          });
          _scrollToBottom();
        }
      },
      onStatus: (status) {
        if (mounted) setState(() => _statusText = status);
      },
    );

    // Finalise the assistant bubble with the complete response
    if (mounted) {
      setState(() {
        _messages[_messages.length - 1] = AgentMessage(
          role: 'assistant',
          content: response.text,
          toolUsed: response.toolUsed,
        );
        _isLoading = false;
        _statusText = '';
      });
      _scrollToBottom();
    }

    await ChatPersistenceService.appendMessage(
      role: 'assistant',
      content: response.text,
      toolUsed: response.toolUsed,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orchestrator = AgentOrchestrator.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faranga Assistant'),
        actions: [
          // Model status chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onLongPress: _runDebugEval,
              child: Chip(
                avatar: Icon(
                  _isReady ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: _isReady ? Colors.green : Colors.orange,
                ),
                label: Text(
                  _isReady ? 'Gemma 2B' : _statusLabel(orchestrator.modelStatus),
                  style: theme.textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
            ),
          ),
          // Clear history button
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear conversation',
              onPressed: () {
                AgentOrchestrator.instance.clearMemory();
                setState(() => _messages.clear());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Privacy notice ──
          Container(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All processing happens on this device. '
                    'Your data never leaves your phone.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Model error banner ──
          if (_modelError != null)
            Container(
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.error_outline,
                      size: 14,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Model failed to load. '
                      'The GPU on this device may not support this model format, '
                      'or there is not enough free RAM. '
                      'Close other apps and restart Faranga to try again.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Model loading indicator ──
          if (!_isReady && _modelError == null)
            const LinearProgressIndicator(minHeight: 2),

          // ── Message list ──
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),

          // ── Status text while loading ──
          if (_isLoading && _statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

          // ── Input row ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _isReady && !_isLoading,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: _isReady
                            ? 'Ask about your spending…'
                            : 'Loading model…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isReady && !_isLoading
                        ? () => _send(_controller.text)
                        : null,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state with suggestion chips ─────────────────

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assistant_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me about your spending',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try one of these:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 13)),
                    onPressed: _isReady ? () => _send(s) : null,
                  ),
              ],
            ),
            if (_historyFilePath != null) ...[
              const SizedBox(height: 32),
              Text(
                'Chat history saved to:\n$_historyFilePath',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Debug evaluation mode (long-press model chip) ─────

  Future<void> _runDebugEval() async {
    if (!_isReady) return;

    const evalQueries = [
      'How much did I spend this month?',
      'What is my budget status?',
      'Show me uncategorized transactions',
      'Find recurring payments',
      'Search for transport payments',
      'What did I spend today?',
      'Show me my top recipients',
      'Hello',
      'Help',
      'What is 2+2',
    ];

    setState(() {
      _messages.add(AgentMessage(
        role: 'assistant',
        content: '🔬 Debug eval started — running ${evalQueries.length} queries…',
      ));
      _isLoading = true;
    });

    final stopwatch = Stopwatch();
    final results = StringBuffer();
    results.writeln('=== Debug Eval ${DateFormat('HH:mm:ss').format(DateTime.now())} ===\n');

    for (final q in evalQueries) {
      stopwatch.reset();
      stopwatch.start();

      final resp = await AgentOrchestrator.instance.handle(q);

      stopwatch.stop();
      results.writeln(
        'Q: $q\n'
        'Tool: ${resp.toolUsed ?? "none"} | ${stopwatch.elapsedMilliseconds}ms\n'
        'A: ${resp.text.substring(0, resp.text.length.clamp(0, 80))}…\n',
      );
    }

    await ChatPersistenceService.appendMessage(
      role: 'assistant',
      content: results.toString(),
    );

    if (mounted) {
      setState(() {
        _messages.add(AgentMessage(
          role: 'assistant',
          content: '✅ Eval complete. Results saved to chat history file.',
        ));
        _isLoading = false;
      });
    }
  }

  String _statusLabel(ModelStatus status) => switch (status) {
        ModelStatus.checking => 'Checking…',
        ModelStatus.needsDownload => 'Need download',
        ModelStatus.loading => 'Loading…',
        ModelStatus.ready => 'Ready',
        ModelStatus.error => 'Error',
      };
}

// ── Message bubble ────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final AgentMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final timeFmt = DateFormat('HH:mm');

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: message.content.isEmpty
                  ? _TypingIndicator(color: theme.colorScheme.onSurfaceVariant)
                  : Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
            ),

            // Tool tag + timestamp
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.toolUsed != null) ...[
                    Icon(
                      Icons.build_outlined,
                      size: 10,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      message.toolUsed!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    timeFmt.format(message.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Typing indicator (three animated dots) ────────────────

class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity =
                ((_ctrl.value * 3 - i).clamp(0.0, 1.0) * (1 - (_ctrl.value * 3 - i - 1).clamp(0.0, 1.0)));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.3 + opacity * 0.7,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: widget.color,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
