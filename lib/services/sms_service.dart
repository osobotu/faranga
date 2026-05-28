import 'package:flutter/services.dart';
import 'momo_parser.dart';
import '../models/transaction.dart';

class SmsService {
  static const _channel = MethodChannel('momo_finance/sms');

  /// Request SMS permission.
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Read MoMo SMS from inbox and parse them.
  static Future<({List<MomoTransaction> parsed, List<String> failed})>
  readAndParseMomoSms() async {
    try {
      final List<dynamic> messages = await _channel.invokeMethod('readSms');
      final smsList = messages.cast<String>();
      return MomoParser.parseBatch(smsList);
    } catch (e) {
      return (parsed: <MomoTransaction>[], failed: <String>[]);
    }
  }
}
