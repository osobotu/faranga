import 'dart:async';
import 'sms_service.dart';
import 'database_service.dart';
import 'category_service.dart';

class SyncManager {
  static Timer? _timer;
  static bool _syncing = false;

  /// Callback for UI updates after sync.
  static void Function(SyncResult result)? onSyncComplete;

  /// Start periodic sync. Runs immediately, then every [interval].
  static void start({Duration interval = const Duration(minutes: 15)}) {
    stop(); // Cancel any existing timer
    // Run once immediately
    sync();
    // Then schedule periodic
    _timer = Timer.periodic(interval, (_) => sync());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Run a single sync cycle.
  static Future<SyncResult> sync() async {
    if (_syncing) return SyncResult.skipped();
    _syncing = true;

    try {
      final result = await SmsService.readAndParseMomoSms();
      final newCount = await DatabaseService.insertBatch(result.parsed);

      final syncResult = SyncResult(
        found: result.parsed.length,
        newTransactions: newCount,
        categorized: 0,
        failed: result.failed.length,
      );

      onSyncComplete?.call(syncResult);
      return syncResult;
    } catch (e) {
      return SyncResult.error(e.toString());
    } finally {
      _syncing = false;
    }
  }
}

class SyncResult {
  final int found;
  final int newTransactions;
  final int categorized;
  final int failed;
  final String? error;
  final bool wasSkipped;

  SyncResult({
    this.found = 0,
    this.newTransactions = 0,
    this.categorized = 0,
    this.failed = 0,
    this.error,
    this.wasSkipped = false,
  });

  factory SyncResult.skipped() => SyncResult(wasSkipped: true);
  factory SyncResult.error(String msg) => SyncResult(error: msg);

  String get message {
    if (wasSkipped) return 'Sync already in progress';
    if (error != null) return 'Sync error: $error';
    if (newTransactions == 0) return 'Up to date';
    return '$newTransactions new transaction(s) added, $categorized auto-categorized.';
  }
}
