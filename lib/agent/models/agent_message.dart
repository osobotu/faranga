class AgentMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final String? toolUsed; // name of tool called, if any
  final DateTime timestamp;

  AgentMessage({
    required this.role,
    required this.content,
    this.toolUsed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
