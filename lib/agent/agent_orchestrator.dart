import 'dart:async';
import 'gemma_llm_service.dart';
import 'local_llm_service.dart';
import 'local_memory_store.dart';
import 'model_download_service.dart';
import 'prompt_builder.dart';
import 'tool_registry.dart';
import 'models/agent_message.dart';
import 'models/agent_response.dart';
import 'tools/spending_summary_tool.dart';
import 'tools/search_transactions_tool.dart';
import 'tools/budget_status_tool.dart';
import 'tools/uncategorized_transactions_tool.dart';
import 'tools/recurring_payments_tool.dart';

// ── Model state ───────────────────────────────────────────

enum ModelStatus {
  checking,
  needsDownload,
  loading,
  ready,
  error,
}

// ── Orchestrator ──────────────────────────────────────────

class AgentOrchestrator {
  static AgentOrchestrator? _instance;
  static AgentOrchestrator get instance {
    _instance ??= AgentOrchestrator._();
    return _instance!;
  }

  AgentOrchestrator._() {
    _registry = _buildRegistry();
    _memory = LocalMemoryStore();
    _readyCompleter = Completer<void>();
    _init();
  }

  late final ToolRegistry _registry;
  late final LocalMemoryStore _memory;
  late LocalLlmService _llm;
  late final Completer<void> _readyCompleter;

  ModelStatus _modelStatus = ModelStatus.checking;
  String? _initError;

  ModelStatus get modelStatus => _modelStatus;
  String? get initError => _initError;
  bool get isReady => _modelStatus == ModelStatus.ready;

  Future<void> get ready => _readyCompleter.future;

  Future<void> _init() async {
    try {
      final downloaded = await ModelDownloadService.isModelDownloaded();
      if (!downloaded) {
        _modelStatus = ModelStatus.needsDownload;
        if (!_readyCompleter.isCompleted) _readyCompleter.completeError('needsDownload');
        return;
      }

      _modelStatus = ModelStatus.loading;
      _llm = GemmaLlmService();
      await _llm.initialize();
      _modelStatus = ModelStatus.ready;

      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    } catch (e) {
      _modelStatus = ModelStatus.error;
      _initError = e.toString();
      // If the file is smaller than expected, it was a partial download.
      // Delete it so the user is sent to the download screen instead of
      // being stuck on an unrecoverable error state.
      if (!await ModelDownloadService.isModelComplete()) {
        try { await ModelDownloadService.deleteModel(); } catch (_) {}
        _modelStatus = ModelStatus.needsDownload;
      }
      if (!_readyCompleter.isCompleted) _readyCompleter.completeError(e);
    }
  }

  Future<void> reinitialize() async {
    _modelStatus = ModelStatus.loading;
    try {
      _llm = GemmaLlmService();
      await _llm.initialize();
      _modelStatus = ModelStatus.ready;
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    } catch (e) {
      _modelStatus = ModelStatus.error;
      _initError = e.toString();
      if (!_readyCompleter.isCompleted) _readyCompleter.completeError(e);
    }
  }

  Future<AgentResponse> handle(
    String userMessage, {
    void Function(String token)? onToken,
    void Function(String status)? onStatus,
  }) async {
    if (!isReady) {
      return AgentResponse.error(
        'The assistant is not ready yet. Please wait for the model to load.',
      );
    }

    final systemPrompt = PromptBuilder.buildSystemPrompt(_registry.toolSchemas);
    final history = PromptBuilder.buildHistory(_memory.recentMessages);

    _memory.add(AgentMessage(role: 'user', content: userMessage));

    try {
      onStatus?.call('Thinking…');

      final decision = await _llm
          .decide(
            systemPrompt: systemPrompt,
            history: history,
            tools: _registry.toolSchemas,
            userMessage: userMessage,
          )
          .timeout(const Duration(seconds: 30));

      if (decision is LlmToolResult) {
        onStatus?.call('Checking your data…');

        final toolResult = await _registry.execute(
          decision.toolCall.toolName,
          decision.toolCall.params,
        );

        onStatus?.call('Preparing response…');

        final responseText = await _llm.synthesize(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          toolName: decision.toolCall.toolName,
          toolResult: toolResult.toContextString(),
          onToken: onToken,
        );

        final reply = AgentMessage(
          role: 'assistant',
          content: responseText,
          toolUsed: decision.toolCall.toolName,
        );
        _memory.add(reply);

        return AgentResponse(
          text: responseText,
          toolUsed: decision.toolCall.toolName,
        );
      } else if (decision is LlmTextResult) {
        _memory.add(AgentMessage(role: 'assistant', content: decision.text));
        return AgentResponse(text: decision.text);
      }

      return AgentResponse.error('Unexpected response from the model.');
    } on TimeoutException {
      return AgentResponse.error(
        'The model took too long to respond. Please try again.',
      );
    } catch (e) {
      return AgentResponse.error('Something went wrong: $e');
    }
  }

  List<AgentMessage> get conversationHistory =>
      List.unmodifiable(_memory.recentMessages);

  void clearMemory() => _memory.clear();

  static ToolRegistry _buildRegistry() {
    return ToolRegistry()
      ..register(SpendingSummaryTool())
      ..register(SearchTransactionsTool())
      ..register(BudgetStatusTool())
      ..register(UncategorizedTransactionsTool())
      ..register(RecurringPaymentsTool());
  }
}
