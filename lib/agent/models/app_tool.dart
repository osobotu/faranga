import 'tool_result.dart';

/// Implementations must never make network requests.
abstract class AppTool {
  String get name;
  String get description;
  Map<String, dynamic> get inputSchema;
  Future<ToolResult> execute(Map<String, dynamic> params);
}
