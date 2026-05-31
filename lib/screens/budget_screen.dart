import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/budget_service.dart';
import '../services/database_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetStatus> _budgets = [];
  bool _loading = true;
  final _fmt = NumberFormat('#,###', 'en');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await BudgetService.checkBudgets();
    setState(() {
      _budgets = budgets;
      _loading = false;
    });
  }

  Future<void> _addBudget() async {
    // Pull categories from the database (built-in + user-created)
    final userCategories = await DatabaseService.getAllCategories();
    final categories = <String?>[null, ...userCategories];

    String? selectedCategory;
    final amountController = TextEditingController();
    final customController = TextEditingController();
    bool showCustomField = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c ?? 'Total (all spending)'),
                    ),
                  ),
                  // Special item to create a new category
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('+ New category...'),
                  ),
                ],
                onChanged: (v) {
                  setDialogState(() {
                    if (v == '__custom__') {
                      showCustomField = true;
                      selectedCategory = null;
                    } else {
                      showCustomField = false;
                      selectedCategory = v;
                    }
                  });
                },
              ),
              if (showCustomField) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    hintText: 'e.g. Gym, Haircut, Gifts...',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly limit (RWF)',
                  hintText: 'e.g. 100000',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && amountController.text.isNotEmpty) {
      final amount = int.tryParse(amountController.text.replaceAll(',', ''));
      if (amount != null && amount > 0) {
        // Use the custom category name if the user typed one
        final category =
            showCustomField && customController.text.trim().isNotEmpty
            ? customController.text.trim()
            : selectedCategory;

        await DatabaseService.setBudget(category, amount);
        await _load();
      }
    }
  }

  Future<void> _deleteBudget(BudgetStatus budget) async {
    final budgets = await DatabaseService.getBudgets();
    final match = budgets.firstWhere(
      (b) =>
          (b['category'] as String?) ==
          (budget.label == 'Total' ? null : budget.label),
      orElse: () => {},
    );

    if (match.containsKey('id')) {
      await DatabaseService.deleteBudget(match['id'] as int);
      await _load();
    }
  }

  Color _progressColor(double pct) {
    if (pct >= 100) return Colors.red;
    if (pct >= 75) return Colors.orange;
    if (pct >= 50) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text('No budgets set', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to set a monthly spending limit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _budgets.length,
              itemBuilder: (context, index) {
                final b = _budgets[index];
                final color = _progressColor(b.percentage);

                return Dismissible(
                  key: ValueKey('${b.label}_budget'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete budget?'),
                        content: Text('Remove the ${b.label} budget?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => _deleteBudget(b),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                b.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${b.percentage.toStringAsFixed(0)}%',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (b.percentage / 100).clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: color.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_fmt.format(b.spent)} / ${_fmt.format(b.budgetAmount)} RWF',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          if (b.isOver)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '⚠ Over budget by ${_fmt.format(b.spent - b.budgetAmount)} RWF',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBudget,
        child: const Icon(Icons.add),
      ),
    );
  }
}
