import 'package:intl/intl.dart';
import '../models/app_tool.dart';
import '../models/tool_result.dart';
import '../../services/database_service.dart';
import '../../models/transaction.dart';

/// Searches local transactions by recipient name, category, or date window.
///
/// Privacy: output strips rawSms and phone fields — only recipient name,
/// amount, category, and date are included in results.
class SearchTransactionsTool implements AppTool {
  static final _fmt = NumberFormat('#,###', 'en');
  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  String get name => 'search_transactions';

  @override
  String get description =>
      'Search local transactions by recipient name, spending category, '
      'or how many days back to look. Returns matching records.';

  @override
  Map<String, dynamic> get inputSchema => {
        'recipient': 'string (optional) — partial recipient name to match',
        'category': 'string (optional) — exact category name',
        'days_back': 'int (optional, default 30) — look-back window in days',
        'limit': 'int (optional, default 10) — max results to return',
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final recipient = (params['recipient'] as String?)?.toUpperCase();
      final category = params['category'] as String?;
      final daysBack = (params['days_back'] as int?) ?? 30;
      final limit = (params['limit'] as int?) ?? 10;

      final all = await DatabaseService.getAll();
      final cutoff = DateTime.now().subtract(Duration(days: daysBack));

      final filtered = all.where((tx) {
        if (tx.timestamp.isBefore(cutoff)) return false;
        if (recipient != null &&
            !tx.recipient.toUpperCase().contains(recipient)) {
          return false;
        }
        if (category != null &&
            (tx.category?.toLowerCase() != category.toLowerCase())) {
          return false;
        }
        return true;
      }).take(limit).toList();

      if (filtered.isEmpty) {
        return ToolResult.ok(
          'No transactions found for the given search in the last $daysBack days.',
        );
      }

      final buf = StringBuffer();
      buf.writeln('Found ${filtered.length} transaction(s):');
      for (final tx in filtered) {
        final sign = tx.type == TransactionType.received ? '+' : '-';
        final cat = tx.category ?? 'Uncategorized';
        final date = _dateFmt.format(tx.timestamp);
        buf.writeln(
          '• $sign${_fmt.format(tx.amount)} RWF — ${tx.recipient} ($cat) on $date',
        );
      }
      return ToolResult.ok(buf.toString().trim());
    } catch (e) {
      return ToolResult.fail('Search failed: $e');
    }
  }
}
