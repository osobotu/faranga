import 'models/agent_message.dart';

class PromptBuilder {
  PromptBuilder._();

  static String buildSystemPrompt(List<Map<String, dynamic>> tools) {
    final toolList = tools
        .map((t) => '- ${t['name']}: ${t['description']}')
        .join('\n');

    return '''You are a private local financial assistant for a Rwandan mobile money app called Faranga.
You help users understand their MTN MoMo spending. All data is stored on-device. Never suggest external lookups.

To call a tool, reply with ONLY this JSON (no other text):
{"action":"call_tool","tool":"TOOL_NAME","params":{}}

To reply directly without a tool:
{"action":"respond","text":"YOUR_RESPONSE"}

Available tools:
$toolList

Rules:
- Always call a tool before answering questions about amounts, categories, or budgets.
- Never invent numbers or transaction data.
- Amounts are in RWF (Rwandan Francs).
- Keep responses concise and friendly.
- Decline requests unrelated to the user's local financial data.''';
  }

  static List<Map<String, String>> buildHistory(
    List<AgentMessage> messages, {
    int maxTurns = 4,
  }) {
    final history =
        messages.isNotEmpty && messages.last.role == 'user'
            ? messages.sublist(0, messages.length - 1)
            : List<AgentMessage>.from(messages);

    final cap = maxTurns * 2;
    final recent =
        history.length > cap ? history.sublist(history.length - cap) : history;

    return recent
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
  }
}
