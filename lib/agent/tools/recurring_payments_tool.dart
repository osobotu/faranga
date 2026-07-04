import 'package:intl/intl.dart';
import '../models/app_tool.dart';
import '../models/tool_result.dart';
import '../../services/analytics_service.dart';

/// Detects merchants or people paid 2+ times — recurring expenses.
///
/// Privacy: output contains only aggregated data (recipient name, count,
/// average amount, category) — no individual transaction timestamps or IDs.
class RecurringPaymentsTool implements AppTool {
  static final _fmt = NumberFormat('#,###', 'en');

  @override
  String get name => 'get_recurring_payments';

  @override
  String get description =>
      'Detect recipients paid 2 or more times — useful for spotting '
      'subscriptions, regular bills, and habitual spending.';

  @override
  Map<String, dynamic> get inputSchema => {};

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final recurring = await AnalyticsService.recurringPayments();

      if (recurring.isEmpty) {
        return ToolResult.ok(
          'No recurring payments detected yet. '
          'They appear once you\'ve paid the same recipient at least twice.',
        );
      }

      final buf = StringBuffer();
      buf.writeln('Recurring payments (paid 2+ times):');

      for (final r in recurring.take(10)) {
        final cat = r.category != null ? ' [${r.category}]' : '';
        buf.writeln(
          '• ${r.name}: ${r.count}x — avg ${_fmt.format(r.average)} RWF per payment$cat',
        );
      }

      return ToolResult.ok(buf.toString().trim());
    } catch (e) {
      return ToolResult.fail('Could not load recurring payments: $e');
    }
  }
}
