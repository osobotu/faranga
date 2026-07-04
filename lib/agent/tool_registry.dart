import 'models/app_tool.dart';
import 'models/tool_result.dart';

/// Only tools registered here can be invoked by the agent.
class ToolRegistry {
  final Map<String, AppTool> _tools = {};

  void register(AppTool tool) => _tools[tool.name] = tool;

  bool has(String name) => _tools.containsKey(name);

  List<String> get registeredNames => _tools.keys.toList();

  List<Map<String, dynamic>> get toolSchemas => _tools.values
      .map(
        (t) => {
          'name': t.name,
          'description': t.description,
          'params': t.inputSchema,
        },
      )
      .toList();

  Future<ToolResult> execute(
    String name,
    Map<String, dynamic> params,
  ) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult.fail('Unknown tool: "$name". Available: ${registeredNames.join(', ')}');
    }
    try {
      return await tool.execute(params);
    } catch (e) {
      return ToolResult.fail('Tool "$name" failed: $e');
    }
  }
}
