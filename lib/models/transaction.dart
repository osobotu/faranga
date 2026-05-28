enum TransactionType { transfer, payment, received }

class MomoTransaction {
  final int? id;
  final String? txId;
  final TransactionType type;
  final int amount;
  final String recipient;
  final String? phone;
  final DateTime timestamp;
  final int fee;
  final int balance;
  final String? category;
  final String rawSms;

  MomoTransaction({
    this.id,
    this.txId,
    required this.type,
    required this.amount,
    required this.recipient,
    this.phone,
    required this.timestamp,
    required this.fee,
    required this.balance,
    this.category,
    required this.rawSms,
  });

  /// Convert to a map for SQLite insertion.
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'tx_id': txId,
    'type': type.name,
    'amount': amount,
    'recipient': recipient,
    'phone': phone,
    'timestamp': timestamp.toIso8601String(),
    'fee': fee,
    'balance': balance,
    'category': category,
    'raw_sms': rawSms,
  };

  /// Reconstruct from a SQLite row.
  factory MomoTransaction.fromMap(Map<String, dynamic> map) => MomoTransaction(
    id: map['id'] as int?,
    txId: map['tx_id'] as String?,
    type: TransactionType.values.byName(map['type'] as String),
    amount: map['amount'] as int,
    recipient: map['recipient'] as String,
    phone: map['phone'] as String?,
    timestamp: DateTime.parse(map['timestamp'] as String),
    fee: map['fee'] as int,
    balance: map['balance'] as int,
    category: map['category'] as String?,
    rawSms: map['raw_sms'] as String,
  );
}
