import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 0)
class Expense extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String category;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String notes;

  @HiveField(5)
  bool isRecurring;

  @HiveField(6)
  String frequency; // 'None', 'Weekly', 'Monthly'

  @HiveField(7)
  String type; // 'expense' or 'income'

  @HiveField(8)
  String id;

  @HiveField(9)
  String bankName;

  @HiveField(10)
  String reference; // UPI Ref No / Transaction ID

  Expense({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes = '',
    this.isRecurring = false,
    this.frequency = 'None',
    this.type = 'expense',
    String? id,
    this.bankName = 'Unknown Bank',
    this.reference = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'notes': notes,
      'isRecurring': isRecurring,
      'frequency': frequency,
      'type': type,
      'bankName': bankName,
      'reference': reference,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      title: map['title'] ?? '',
      category: map['category'] ?? 'Other',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      amount: (map['amount'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
      isRecurring: map['isRecurring'] ?? false,
      frequency: map['frequency'] ?? 'None',
      type: map['type'] ?? 'expense',
      bankName: map['bankName'] ?? 'Unknown Bank',
      reference: map['reference'] ?? '',
    );
  }
}
