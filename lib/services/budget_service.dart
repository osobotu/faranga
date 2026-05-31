import 'database_service.dart';
import 'analytics_service.dart';

class BudgetStatus {
  final String label;
  final int budgetAmount;
  final int spent;
  final double percentage;
  final bool isOver;

  BudgetStatus({
    required this.label,
    required this.budgetAmount,
    required this.spent,
    required this.percentage,
    required this.isOver,
  });
}

class BudgetService {
  /// Check all budgets against current month spending.
  static Future<List<BudgetStatus>> checkBudgets() async {
    final budgets = await DatabaseService.getBudgets();
    if (budgets.isEmpty) return [];

    final byCategory = await AnalyticsService.spendingByCategory();
    final summary = await AnalyticsService.getSpendingSummary();

    final results = <BudgetStatus>[];

    for (final budget in budgets) {
      final category = budget['category'] as String?;
      final amount = budget['amount'] as int;

      int spent;
      String label;

      if (category == null) {
        spent = summary.thisMonth;
        label = 'Total';
      } else {
        final match = byCategory.where((c) => c.category == category);
        spent = match.isNotEmpty ? match.first.total : 0;
        label = category;
      }

      final pct = amount > 0 ? (spent / amount) * 100 : 0.0;

      results.add(
        BudgetStatus(
          label: label,
          budgetAmount: amount,
          spent: spent,
          percentage: pct,
          isOver: pct >= 100,
        ),
      );
    }

    results.sort((a, b) => b.percentage.compareTo(a.percentage));
    return results;
  }

  /// Get budgets that have crossed 50% (for notifications).
  static Future<List<BudgetStatus>> getAlerts() async {
    final all = await checkBudgets();
    return all.where((b) => b.percentage >= 50).toList();
  }
}
