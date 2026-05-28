import '../models/transaction.dart';

class MomoParser {
  /// P2P transfer:
  /// *165*S*2200 RWF transferred to FirstName LastName (2507xxxxxxx) at 2026-05-26 11:30:14 .Fee: 100RWF.Balance: 19228RWF...
  static final _p2pPattern = RegExp(
    r'\*165\*S\*'
    r'([\d,]+)\s*RWF\s+transferred\s+to\s+'
    r'(.+?)\s*'
    r'\((\d+)\)\s*'
    r'at\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*'
    r'\.Fee:\s*([\d,]+)\s*RWF'
    r'\.Balance:\s*([\d,]+)\s*RWF',
  );

  /// Merchant payment:
  /// TxId:28156880875*S*Your payment of 3,300 RWF to Company Name Ltd 8830380 was completed at 2026-05-26 20:29:39.  Balance: 12,808 RWF. Fee 0 RWF.
  static final _merchantPattern = RegExp(
    r'TxId:(\d+)\*S\*'
    r'Your\s+payment\s+of\s+'
    r'([\d,]+)\s*RWF\s+to\s+'
    r'(.+?)\s+'
    r'(\d+)\s+'
    r'was\s+completed\s+at\s+'
    r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})'
    r'.*?Balance:\s*([\d,]+)\s*RWF'
    r'.*?Fee\s+([\d,]+)\s*RWF',
  );

  /// Received money:
  /// You have received 7000 RWF from FIRSTNAME LASTNAME MIDDLENAME (*********940) at 2026-05-22 21:44:48 . Balance:18318 RWF. FT Id: 28077221915.
  /// You have received 40000 RWF from NAME (*********572) at 2026-05-24 15:14:37. Message from sender: ... Balance:74028 RWF. FT Id: 28108307267.
  static final _receivedPattern = RegExp(
    r'You\s+have\s+received\s+'
    r'([\d,]+)\s*RWF\s+from\s+' // amount
    r'(.+?)\s*' // sender name
    r'\(\*+(\d+)\)\s*' // masked phone — captures visible digits
    r'at\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})' // datetime
    r'.*?Balance:\s*([\d,]+)\s*RWF' // balance (skips optional "Message from sender:" in between)
    r'.*?FT\s*Id:\s*(\d+)', // transaction ID
  );

  static int _parseAmount(String s) => int.parse(s.replaceAll(',', ''));

  /// Parse a single SMS body. Returns null if format not recognised.
  static MomoTransaction? parse(String sms) {
    // Try P2P transfer
    var m = _p2pPattern.firstMatch(sms);
    if (m != null) {
      return MomoTransaction(
        type: TransactionType.transfer,
        amount: _parseAmount(m.group(1)!),
        recipient: m.group(2)!.trim(),
        phone: m.group(3),
        timestamp: DateTime.parse(m.group(4)!),
        fee: _parseAmount(m.group(5)!),
        balance: _parseAmount(m.group(6)!),
        rawSms: sms,
      );
    }

    // Try merchant payment
    m = _merchantPattern.firstMatch(sms);
    if (m != null) {
      return MomoTransaction(
        txId: m.group(1),
        type: TransactionType.payment,
        amount: _parseAmount(m.group(2)!),
        recipient: m.group(3)!.trim(),
        phone: m.group(4),
        timestamp: DateTime.parse(m.group(5)!),
        balance: _parseAmount(m.group(6)!),
        fee: _parseAmount(m.group(7)!),
        rawSms: sms,
      );
    }

    // Try received money
    m = _receivedPattern.firstMatch(sms);
    if (m != null) {
      return MomoTransaction(
        txId: m.group(6),
        type: TransactionType.received,
        amount: _parseAmount(m.group(1)!),
        recipient: m.group(2)!.trim(),
        phone: m.group(3), // only the visible digits (e.g. "572")
        timestamp: DateTime.parse(m.group(4)!),
        fee: 0,
        balance: _parseAmount(m.group(5)!),
        rawSms: sms,
      );
    }

    return null;
  }

  /// Parse a batch of SMS messages. Returns parsed and unparsed separately.
  static ({List<MomoTransaction> parsed, List<String> failed}) parseBatch(
    List<String> messages,
  ) {
    final parsed = <MomoTransaction>[];
    final failed = <String>[];

    for (final sms in messages) {
      final tx = parse(sms);
      if (tx != null) {
        parsed.add(tx);
      } else {
        failed.add(sms);
      }
    }

    return (parsed: parsed, failed: failed);
  }
}
