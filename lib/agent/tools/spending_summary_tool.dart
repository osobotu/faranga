import '../models/app_tool.dart';
import '../models/tool_result.dart';
import '../../services/analytics_service.dart';

/// Privacy: output contains only aggregated totals and category names.
class SpendingSummaryTool implements AppTool {
  @override
  String get name => 'get_spending_summary';

  @override
  String get description =>
      'Get spending totals for today, this week, and this month vs last month. '
      'Includes breakdown by category and top recipients.';

  @override
  Map<String, dynamic> get inputSchema => {};

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final text = await AnalyticsService.generateTextSummary();
      return ToolResult.ok(text);
    } catch (e) {
      return ToolResult.fail('Could not load spending data: $e');
    }
  }
}
