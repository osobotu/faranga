/// The result of a local tool execution.
class ToolResult {
  final bool success;
  final dynamic data;
  final String? error;

  const ToolResult._({required this.success, this.data, this.error});

  factory ToolResult.ok(dynamic data) =>
      ToolResult._(success: true, data: data);

  factory ToolResult.fail(String error) =>
      ToolResult._(success: false, error: error);

  String toContextString() {
    if (!success) return 'Error: $error';
    if (data is String) return data as String;
    return data?.toString() ?? '';
  }
}
