import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  SpendingSummary? _summary;
  List<CategoryTotal> _byCategory = [];
  List<RecipientTotal> _topRecipients = [];
  List<DayOfWeekSpending> _byDay = [];
  bool _loading = true;

  final _fmt = NumberFormat('#,###', 'en');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await AnalyticsService.getSpendingSummary();
    final byCategory = await AnalyticsService.spendingByCategory();
    final topRecipients = await AnalyticsService.topRecipients();
    final byDay = await AnalyticsService.spendingByDayOfWeek();

    setState(() {
      _summary = summary;
      _byCategory = byCategory;
      _topRecipients = topRecipients;
      _byDay = byDay;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Month over month ──
          if (_summary != null) ...[
            _SectionTitle('Month over Month'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This month',
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            '${_fmt.format(_summary!.thisMonth)} RWF',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last month',
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            '${_fmt.format(_summary!.lastMonth)} RWF',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    _ChangeChip(change: _summary!.monthOverMonthChange),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Spending by category ──
          _SectionTitle('By Category'),
          if (_byCategory.isEmpty)
            const Text('No data yet')
          else ...[
            for (final cat in _byCategory)
              _CategoryBar(
                category: cat.category,
                amount: cat.total,
                count: cat.count,
                maxAmount: _byCategory.first.total,
                fmt: _fmt,
              ),
          ],
          const SizedBox(height: 24),

          // ── Day of week ──
          _SectionTitle('Spending by Day'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in _byDay) ...[
                    Expanded(
                      child: _DayBar(
                        data: d,
                        max: _byDay
                            .map((d) => d.total)
                            .reduce((a, b) => a > b ? a : b),
                        fmt: _fmt,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Top recipients ──
          _SectionTitle('Top Recipients'),
          for (final r in _topRecipients)
            ListTile(
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${r.count}x · avg ${_fmt.format(r.average)} RWF${r.category != null ? ' · ${r.category}' : ''}',
              ),
              trailing: Text(
                '${_fmt.format(r.total)} RWF',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class _ChangeChip extends StatelessWidget {
  final double change;
  const _ChangeChip({required this.change});

  @override
  Widget build(BuildContext context) {
    final isUp = change > 0;
    final color = isUp ? Colors.red : Colors.green;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        '${change.abs().toStringAsFixed(0)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String category;
  final int amount;
  final int count;
  final int maxAmount;
  final NumberFormat fmt;

  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.count,
    required this.maxAmount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount > 0 ? amount / maxAmount : 0.0;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$category ($count)', style: theme.textTheme.bodySmall),
              Text(
                '${fmt.format(amount)} RWF',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final DayOfWeekSpending data;
  final int max;
  final NumberFormat fmt;

  const _DayBar({required this.data, required this.max, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? data.total / max : 0.0;
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          fmt.format(data.total),
          style: theme.textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          height: 80 * fraction,
          width: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(data.day, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
