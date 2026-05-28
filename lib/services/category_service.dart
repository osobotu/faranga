import 'database_service.dart';
import '../models/transaction.dart';

class CategoryService {
  /// Apply category rules to all uncategorized transactions.
  /// Returns how many were categorized.
  static Future<int> autoCategorize() async {
    final rules = await DatabaseService.getCategoryRules();
    final transactions = await DatabaseService.getAll();

    int categorized = 0;

    for (final tx in transactions) {
      if (tx.category != null) continue;

      final recipientUpper = tx.recipient.toUpperCase();
      for (final rule in rules) {
        final pattern = rule['pattern'] as String;
        if (recipientUpper.contains(pattern)) {
          await DatabaseService.updateCategory(
            tx.id!,
            rule['category'] as String,
          );
          categorized++;
          break;
        }
      }
    }

    return categorized;
  }

  /// Get all transactions that still need a category.
  static Future<List<MomoTransaction>> getUncategorized() async {
    final all = await DatabaseService.getAll();
    return all.where((tx) => tx.category == null).toList();
  }

  /// Label a specific recipient — creates a rule and applies it
  /// to all matching past transactions.
  static Future<int> labelRecipient(String recipient, String category) async {
    // Use the full recipient name as the pattern
    await DatabaseService.addCategoryRule(recipient.toUpperCase(), category);

    // Apply retroactively
    final all = await DatabaseService.getAll();
    int updated = 0;
    for (final tx in all) {
      if (tx.recipient.toUpperCase() == recipient.toUpperCase() &&
          tx.category != category) {
        await DatabaseService.updateCategory(tx.id!, category);
        updated++;
      }
    }
    return updated;
  }
}
