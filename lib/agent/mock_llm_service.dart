import 'local_llm_service.dart';

/// Keyword-routing mock. Swap into AgentOrchestrator._init to test the pipeline without the model.
class MockLlmService extends LocalLlmService {
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _ready = true;
  }

  @override
  Future<LlmDecision> decide({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required List<Map<String, dynamic>> tools,
    required String userMessage,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final q = userMessage.toLowerCase();

    if (_any(q, ['budget', 'limit', 'over budget'])) {
      return LlmToolResult(ToolCall(toolName: 'get_budget_status', params: {}));
    }
    if (_any(q, ['recurring', 'repeat', 'subscription', 'regular'])) {
      return LlmToolResult(ToolCall(toolName: 'get_recurring_payments', params: {}));
    }
    if (_any(q, ['uncategorized', 'not categorized', 'label', 'review'])) {
      return LlmToolResult(ToolCall(toolName: 'get_uncategorized_transactions', params: {}));
    }
    if (_any(q, ['search', 'find', 'show me', 'payments to', 'sent to'])) {
      final params = <String, dynamic>{};
      for (final cat in ['Transport', 'Food & Dining', 'Groceries', 'Health', 'Utilities']) {
        if (q.contains(cat.toLowerCase())) {
          params['category'] = cat;
          break;
        }
      }
      return LlmToolResult(ToolCall(toolName: 'search_transactions', params: params));
    }
    if (_any(q, ['spent', 'spending', 'summary', 'total', 'how much', 'month', 'week', 'today', 'analytics'])) {
      return LlmToolResult(ToolCall(toolName: 'get_spending_summary', params: {}));
    }

    return LlmTextResult(_fallback(q));
  }

  @override
  Future<String> synthesize({
    required String systemPrompt,
    required String userMessage,
    required String toolName,
    required String toolResult,
    void Function(String token)? onToken,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    onToken?.call(toolResult);
    return toolResult;
  }

  @override
  Future<void> dispose() async => _ready = false;

  bool _any(String q, List<String> kws) => kws.any(q.contains);

  String _fallback(String q) {
    if (_any(q, ['hello', 'hi', 'hey'])) {
      return 'Hello! Ask me about your MoMo spending — try "How much did I spend this month?"';
    }
    if (_any(q, ['help', 'what can you do'])) {
      return 'I can help with:\n• Spending summaries (today / week / month)\n• Budget status\n• Uncategorized transactions\n• Recurring payments\n• Searching transactions by category or recipient';
    }
    return 'I can help you review your MoMo spending. Try asking "How much did I spend this month?" or "What\'s my budget status?".';
  }
}
