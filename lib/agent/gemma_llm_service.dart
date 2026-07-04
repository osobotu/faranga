import 'dart:async';
import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'local_llm_service.dart';

/// On-device LLM using flutter_gemma 0.3.x (MediaPipe Gemma 2B-IT).
/// The plugin stores the model at `<app-documents>/model.bin` — no path management needed here.
class GemmaLlmService extends LocalLlmService {
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    await FlutterGemmaPlugin.instance.init(
      maxTokens: 1024,
      temperature: 0.7,
      randomSeed: 42,
      topK: 40,
    );
    // The Dart plugin silently swallows Kotlin-side init errors without
    // rethrowing — isInitialized surfaces them so we don't set _ready = true
    // while inferenceModel is uninitialized, which would cause a native crash.
    await FlutterGemmaPlugin.instance.isInitialized;
    _ready = true;
  }

  // ── decide ────────────────────────────────────────────

  @override
  Future<LlmDecision> decide({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required List<Map<String, dynamic>> tools,
    required String userMessage,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final prompt = _buildDecisionPrompt(systemPrompt, history, userMessage);

    final raw = await _collectStream(
      FlutterGemmaPlugin.instance.getChatResponseAsync(
        messages: [Message(text: prompt, isUser: true)],
        chatContextLength: 1,
      ),
    ).timeout(timeout);

    return _parseDecision(raw.trim());
  }

  // ── synthesize ────────────────────────────────────────

  @override
  Future<String> synthesize({
    required String systemPrompt,
    required String userMessage,
    required String toolName,
    required String toolResult,
    void Function(String token)? onToken,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final prompt = _buildSynthesisPrompt(
      systemPrompt,
      userMessage,
      toolName,
      toolResult,
    );

    final buffer = StringBuffer();

    await FlutterGemmaPlugin.instance
        .getChatResponseAsync(
          messages: [Message(text: prompt, isUser: true)],
          chatContextLength: 1,
        )
        .timeout(timeout)
        .forEach((token) {
          if (token != null && token.isNotEmpty) {
            buffer.write(token);
            onToken?.call(token);
          }
        });

    return buffer.toString().trim();
  }

  @override
  Future<void> dispose() async => _ready = false;

  // ── prompt builders ───────────────────────────────────

  String _buildDecisionPrompt(
    String systemPrompt,
    List<Map<String, String>> history,
    String userMessage,
  ) {
    final buf = StringBuffer();
    buf.writeln(systemPrompt);

    if (history.isNotEmpty) {
      buf.writeln('\nConversation so far:');
      for (final m in history) {
        final label = m['role'] == 'user' ? 'User' : 'Assistant';
        buf.writeln('$label: ${m['content']}');
      }
    }

    buf.writeln('\nUser: $userMessage');
    buf.writeln('\nYour JSON response (nothing else):');
    return buf.toString();
  }

  String _buildSynthesisPrompt(
    String systemPrompt,
    String userMessage,
    String toolName,
    String toolResult,
  ) =>
      '''$systemPrompt

The user asked: "$userMessage"

You used the "$toolName" tool and received this data:
$toolResult

Respond to the user in clear, friendly language using the data above.
Do not output JSON. Do not invent numbers. Keep it concise.''';

  // ── helpers ───────────────────────────────────────────

  Future<String> _collectStream(Stream<String?> stream) async {
    final buf = StringBuffer();
    await for (final token in stream) {
      if (token != null) buf.write(token);
    }
    return buf.toString();
  }

  LlmDecision _parseDecision(String raw) {
    // Small models sometimes prepend text before the JSON — extract first object.
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    if (jsonMatch != null) {
      try {
        final map = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final action = map['action'] as String?;

        if (action == 'call_tool') {
          return LlmToolResult(ToolCall(
            toolName: (map['tool'] as String?) ?? '',
            params: (map['params'] as Map<String, dynamic>?) ?? {},
          ));
        }
        if (action == 'respond') {
          return LlmTextResult((map['text'] as String?) ?? raw);
        }
      } catch (_) {
        // JSON parse failed — treat as plain text response
      }
    }

    return LlmTextResult(
      raw.isEmpty ? 'Sorry, I couldn\'t generate a response.' : raw,
    );
  }
}
