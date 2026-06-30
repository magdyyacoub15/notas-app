// في ملف lib/models/transaction.dart

class Transaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final String type; // 'Income' or 'Expense'
  final String partyType; // 'General', 'Customer', 'Supplier'
  final String category;
  final String? notes;
  final String? phoneNumber;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.partyType,
    required this.category,
    this.notes,
    this.phoneNumber,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: map['amount'] as double,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      type: map['type'] as String,
      partyType: map['partyType'] as String,
      category: map['category'] as String,
      notes: map['notes'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'type': type,
      'partyType': partyType,
      'category': category,
      'notes': notes,
      'phoneNumber': phoneNumber,
    };
  }
}