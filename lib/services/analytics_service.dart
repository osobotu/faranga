import '../models/transaction.dart';
import 'database_service.dart';

class SpendingSummary {
  final int today;
  final int thisWeek;
  final int thisMonth;
  final int lastMonth;
  final double monthOverMonthChange; // percentage

  SpendingSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.lastMonth,
    required this.monthOverMonthChange,
  });
}

class RecipientTotal {
  final String name;
  final String? category;
  final int total;
  final int count;

  RecipientTotal({
    required this.name,
    this.category,
    required this.total,
    required this.count,
  });

  int get average => count > 0 ? total ~/ count : 0;
}

class CategoryTotal {
  final String category;
  final int total;
  final int count;

  CategoryTotal({
    required this.category,
    required this.total,
    required this.count,
  });
}

class DayOfWeekSpending {
  final String day;
  final int total;
  final int count;

  DayOfWeekSpending({
    required this.day,
    required this.total,
    required this.count,
  });
}

class AnalyticsService {
  static final _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Overall spending summary with month-over-month comparison.
  static Future<SpendingSummary> getSpendingSummary() async {
    final all = await DatabaseService.getAll();
    final now = DateTime.now();

    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    int sum(DateTime from, DateTime to) => all
        .where(
          (tx) =>
              tx.type != TransactionType.received &&
              tx.timestamp.isAfter(from) &&
              tx.timestamp.isBefore(to),
        )
        .fold(0, (total, tx) => total + tx.amount + tx.fee);

    final thisMonth = sum(monthStart, now);
    final lastMonth = sum(lastMonthStart, monthStart);

    final change = lastMonth > 0
        ? ((thisMonth - lastMonth) / lastMonth) * 100
        : 0.0;

    return SpendingSummary(
      today: sum(todayStart, now),
      thisWeek: sum(weekStart, now),
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      monthOverMonthChange: change,
    );
  }

  /// Top recipients ranked by total amount spent.
  static Future<List<RecipientTotal>> topRecipients({int limit = 10}) async {
    final all = await DatabaseService.getAll();
    final map = <String, RecipientTotal>{};

    for (final tx in all) {
      final key = tx.recipient.toUpperCase();
      final existing = map[key];
      if (existing != null) {
        map[key] = RecipientTotal(
          name: tx.recipient,
          category: tx.category ?? existing.category,
          total: existing.total + tx.amount,
          count: existing.count + 1,
        );
      } else {
        map[key] = RecipientTotal(
          name: tx.recipient,
          category: tx.category,
          total: tx.amount,
          count: 1,
        );
      }
    }

    final sorted = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return sorted.take(limit).toList();
  }

  /// Spending grouped by category.
  static Future<List<CategoryTotal>> spendingByCategory() async {
    final all = await DatabaseService.getAll();
    final map = <String, CategoryTotal>{};

    for (final tx in all) {
      final cat = tx.category ?? 'Uncategorized';
      final existing = map[cat];
      if (existing != null) {
        map[cat] = CategoryTotal(
          category: cat,
          total: existing.total + tx.amount,
          count: existing.count + 1,
        );
      } else {
        map[cat] = CategoryTotal(category: cat, total: tx.amount, count: 1);
      }
    }

    final sorted = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return sorted;
  }

  /// Spending pattern by day of week.
  static Future<List<DayOfWeekSpending>> spendingByDayOfWeek() async {
    final all = await DatabaseService.getAll();
    final totals = List.filled(7, 0);
    final counts = List.filled(7, 0);

    for (final tx in all) {
      final dow = tx.timestamp.weekday - 1; // 0 = Monday
      totals[dow] += tx.amount;
      counts[dow]++;
    }

    return List.generate(
      7,
      (i) => DayOfWeekSpending(
        day: _dayNames[i],
        total: totals[i],
        count: counts[i],
      ),
    );
  }

  /// Daily spending for the last N days (for trend chart).
  static Future<List<MapEntry<DateTime, int>>> dailySpending({
    int days = 30,
  }) async {
    final all = await DatabaseService.getAll();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    final map = <DateTime, int>{};
    // Initialize all days to 0
    for (int i = 0; i <= days; i++) {
      final day = start.add(Duration(days: i));
      map[DateTime(day.year, day.month, day.day)] = 0;
    }

    for (final tx in all) {
      final day = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      if (day.isAfter(start)) {
        map[day] = (map[day] ?? 0) + tx.amount;
      }
    }

    return map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Detect likely recurring payments (same recipient, 2+ times).
  static Future<List<RecipientTotal>> recurringPayments() async {
    final top = await topRecipients(limit: 50);
    return top.where((r) => r.count >= 2).toList();
  }

  /// Quick text summary for the LLM context (Layer 3 prep).
  static Future<String> generateTextSummary() async {
    final summary = await getSpendingSummary();
    final byCategory = await spendingByCategory();
    final topRec = await topRecipients(limit: 5);
    final byDay = await spendingByDayOfWeek();

    final buf = StringBuffer();
    buf.writeln('=== SPENDING SUMMARY ===');
    buf.writeln('Today: ${summary.today} RWF');
    buf.writeln('This week: ${summary.thisWeek} RWF');
    buf.writeln('This month: ${summary.thisMonth} RWF');
    buf.writeln('Last month: ${summary.lastMonth} RWF');
    buf.writeln(
      'Month-over-month: ${summary.monthOverMonthChange.toStringAsFixed(1)}%',
    );

    buf.writeln('\n=== BY CATEGORY ===');
    for (final c in byCategory) {
      buf.writeln('${c.category}: ${c.total} RWF (${c.count} transactions)');
    }

    buf.writeln('\n=== TOP RECIPIENTS ===');
    for (final r in topRec) {
      buf.writeln(
        '${r.name}: ${r.total} RWF (${r.count}x, avg ${r.average} RWF)',
      );
    }

    buf.writeln('\n=== DAY OF WEEK PATTERN ===');
    for (final d in byDay) {
      buf.writeln('${d.day}: ${d.total} RWF (${d.count} transactions)');
    }

    return buf.toString();
  }
}
