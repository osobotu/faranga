import 'models/agent_message.dart';

/// Not persisted to SQLite — chat history is in [ChatPersistenceService].
class LocalMemoryStore {
  static const int maxMessages = 20;

  final List<AgentMessage> _messages = [];

  void add(AgentMessage message) {
    _messages.add(message);
    if (_messages.length > maxMessages) {
      _messages.removeAt(0);
    }
  }

  List<AgentMessage> get recentMessages => List.unmodifiable(_messages);

  int get length => _messages.length;

  void clear() => _messages.clear();
}
