import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'momo_parser.dart';
import 'database_service.dart';

class NotificationService {
  static const _smsChannel = MethodChannel('faranga/sms');
  static const _smsEvents = EventChannel('faranga/sms_events');
  static StreamSubscription? _subscription;

  static void Function()? onNewTransaction;

  static void startListening() {
    _subscription?.cancel();
    _subscription = _smsEvents.receiveBroadcastStream().listen((smsBody) async {
      if (smsBody is! String) return;

      final tx = MomoParser.parse(smsBody);
      if (tx == null) return;

      final inserted = await DatabaseService.insert(tx);
      if (!inserted) return;

      // Only notify for transactions after first use
      final prefs = await SharedPreferences.getInstance();
      final firstUseStr = prefs.getString('first_use_date');
      final firstUse = firstUseStr != null ? DateTime.parse(firstUseStr) : null;

      if (firstUse != null && tx.timestamp.isAfter(firstUse)) {
        // Reload to get the DB id
        final all = await DatabaseService.getAll();
        final saved = all.firstWhere(
          (t) => t.rawSms == smsBody,
          orElse: () => tx,
        );

        if (saved.id != null) {
          await _showTransactionNotification(
            saved.id!,
            saved.amount,
            saved.recipient,
          );
        }
      }

      onNewTransaction?.call();
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<void> _showTransactionNotification(
    int dbId,
    int amount,
    String recipient,
  ) async {
    final categories = await DatabaseService.getAllCategories();
    final topThree = categories.take(3).toList();
    if (topThree.isEmpty) {
      topThree.addAll(['Transport', 'Groceries', 'Food & Dining']);
    }

    try {
      await _smsChannel.invokeMethod('showTransactionNotification', {
        'dbId': dbId,
        'amount': amount.toString(),
        'recipient': recipient,
        'categories': topThree,
      });
    } catch (e) {
      // Notification permission might not be granted
    }
  }
}
