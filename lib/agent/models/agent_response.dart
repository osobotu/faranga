class AgentResponse {
  final String text;
  final String? toolUsed;
  final bool isError;

  const AgentResponse({
    required this.text,
    this.toolUsed,
    this.isError = false,
  });

  factory AgentResponse.error(String message) =>
      AgentResponse(text: message, isError: true);
}
