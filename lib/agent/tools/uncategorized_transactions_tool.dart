import 'package:intl/intl.dart';
import '../models/app_tool.dart';
import '../models/tool_result.dart';
import '../../services/category_service.dart';

/// Lists transactions that still need a category.
///
/// Privacy: output contains recipient name, amount, and date only —
/// no raw SMS text or phone numbers.
class UncategorizedTransactionsTool implements AppTool {
  static final _fmt = NumberFormat('#,###', 'en');
  static final _dateFmt = DateFormat('MMM d');

  @override
  String get name => 'get_uncategorized_transactions';

  @override
  String get description =>
      'List transactions that have no spending category yet. '
      'Useful for prompting the user to review and label them.';

  @override
  Map<String, dynamic> get inputSchema => {
        'limit': 'int (optional, default 5) — max items to return',
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final limit = (params['limit'] as int?) ?? 5;
      final uncategorized = await CategoryService.getUncategorized();

      if (uncategorized.isEmpty) {
        return ToolResult.ok('All transactions are categorized. ');
      }

      final shown = uncategorized.take(limit).toList();
      final buf = StringBuffer();
      buf.writeln('${uncategorized.length} uncategorized transaction(s):');

      for (final tx in shown) {
        buf.writeln(
          '• ${tx.recipient} — ${_fmt.format(tx.amount)} RWF on ${_dateFmt.format(tx.timestamp)}',
        );
      }

      if (uncategorized.length > limit) {
        buf.writeln(
          '...and ${uncategorized.length - limit} more. Open the Review screen to categorize them.',
        );
      } else {
        buf.writeln('Open the Review screen to assign categories.');
      }

      return ToolResult.ok(buf.toString().trim());
    } catch (e) {
      return ToolResult.fail('Could not load uncategorized transactions: $e');
    }
  }
}
