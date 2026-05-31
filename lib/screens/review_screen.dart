import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<MomoTransaction> _uncategorized = [];
  bool _loading = true;
  bool _showAll = false;
  DateTime? _firstUseDate;

  final _fmt = NumberFormat('#,###', 'en');

  static const _defaultCategories = [
    'Transport',
    'Groceries',
    'Food & Dining',
    'Utilities',
    'Health',
    'Education',
    'Housing',
    'Telecom',
    'Entertainment',
    'Savings',
    'Donations',
    'Personal',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final firstUseStr = prefs.getString('first_use_date');
    _firstUseDate = firstUseStr != null ? DateTime.parse(firstUseStr) : null;

    final all = await DatabaseService.getAll();
    final uncategorized = all.where((tx) => tx.category == null).toList();

    setState(() {
      if (_showAll || _firstUseDate == null) {
        _uncategorized = uncategorized;
      } else {
        _uncategorized = uncategorized
            .where((tx) => tx.timestamp.isAfter(_firstUseDate!))
            .toList();
      }
      _loading = false;
    });
  }

  Future<void> _categorize(MomoTransaction tx, String category) async {
    await DatabaseService.updateCategory(tx.id!, category);
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tx.recipient} → $category'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showCustomCategoryDialog(MomoTransaction tx) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Gym, Haircut, Gifts...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _categorize(tx, result);
    }
  }

  void _toggleShowAll() {
    setState(() {
      _showAll = !_showAll;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Review (${_uncategorized.length})'),
        actions: [
          TextButton.icon(
            onPressed: _toggleShowAll,
            icon: Icon(
              _showAll ? Icons.filter_list : Icons.filter_list_off,
              size: 18,
            ),
            label: Text(_showAll ? 'New only' : 'Show all'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _uncategorized.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('All caught up!', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _showAll
                        ? 'Every transaction is categorized.'
                        : 'No new uncategorized transactions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (!_showAll) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _toggleShowAll,
                      child: const Text('Review older transactions'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _uncategorized.length,
              itemBuilder: (context, index) {
                final tx = _uncategorized[index];
                final dateStr = DateFormat('MMM d, HH:mm').format(tx.timestamp);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                tx.recipient,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${tx.type == TransactionType.received ? '+' : '-'}${_fmt.format(tx.amount)} RWF',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: tx.type == TransactionType.received
                                    ? Colors.green
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final cat in _defaultCategories)
                              ActionChip(
                                label: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _categorize(tx, cat),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Custom',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _showCustomCategoryDialog(tx),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
