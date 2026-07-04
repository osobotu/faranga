// ── Tool call types ───────────────────────────────────────

class ToolCall {
  final String toolName;
  final Map<String, dynamic> params;
  const ToolCall({required this.toolName, required this.params});
}

// ── LLM decision (sealed) ─────────────────────────────────

class LlmToolDecision {
  final ToolCall toolCall;
  const LlmToolDecision(this.toolCall);
}

class LlmTextDecision {
  final String text;
  const LlmTextDecision(this.text);
}

// ignore: one_member_abstracts
sealed class LlmDecision {}

class LlmToolResult extends LlmDecision {
  final ToolCall toolCall;
  LlmToolResult(this.toolCall);
}

class LlmTextResult extends LlmDecision {
  final String text;
  LlmTextResult(this.text);
}

// ── Abstract service ─────────────────────────────────────

/// All implementations must run inference on-device with no network calls.
abstract class LocalLlmService {
  bool get isReady;

  Future<void> initialize();

  Future<LlmDecision> decide({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required List<Map<String, dynamic>> tools,
    required String userMessage,
    Duration timeout = const Duration(seconds: 30),
  });

  Future<String> synthesize({
    required String systemPrompt,
    required String userMessage,
    required String toolName,
    required String toolResult,
    void Function(String token)? onToken,
    Duration timeout = const Duration(seconds: 30),
  });

  Future<void> dispose();
}
