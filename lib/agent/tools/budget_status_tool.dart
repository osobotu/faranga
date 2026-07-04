import 'package:intl/intl.dart';
import '../models/app_tool.dart';
import '../models/tool_result.dart';
import '../../services/budget_service.dart';

/// Returns the current budget usage for all configured categories.
///
/// Privacy: output contains only category names and aggregate amounts —
/// no individual transaction details.
class BudgetStatusTool implements AppTool {
  static final _fmt = NumberFormat('#,###', 'en');

  @override
  String get name => 'get_budget_status';

  @override
  String get description =>
      'Check how much of each monthly budget has been spent. '
      'Shows percentage used and highlights over-budget categories.';

  @override
  Map<String, dynamic> get inputSchema => {};

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final budgets = await BudgetService.checkBudgets();

      if (budgets.isEmpty) {
        return ToolResult.ok(
          'No budgets are set yet. You can add them from the Budgets screen.',
        );
      }

      final buf = StringBuffer();
      buf.writeln('Budget status this month:');

      for (final b in budgets) {
        final pct = b.percentage.toStringAsFixed(0);
        final status = b.isOver
            ? '⚠ OVER by ${_fmt.format(b.spent - b.budgetAmount)} RWF'
            : b.percentage >= 75
                ? '⚠ Near limit ($pct%)'
                : '✓ OK ($pct%)';
        buf.writeln(
          '• ${b.label}: ${_fmt.format(b.spent)} / ${_fmt.format(b.budgetAmount)} RWF — $status',
        );
      }

      return ToolResult.ok(buf.toString().trim());
    } catch (e) {
      return ToolResult.fail('Could not load budget data: $e');
    }
  }
}
