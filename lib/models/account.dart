import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para o método toString, se necessário

var uuid = Uuid();

class Account {
  final String id;
  final String categoryId;
  String name;
  DateTime dueDate;
  double? value;
  bool isPaid;

  // Campos para Recorrência
  bool isRecurring;
  int? recurringDayOfMonth;
  DateTime? lastPaidDate; // Usando este nome consistentemente

  Account({
    String? id,
    required this.categoryId,
    required this.name,
    required this.dueDate,
    this.value,
    this.isPaid = false,
    this.isRecurring = false,
    this.recurringDayOfMonth,
    this.lastPaidDate,
  }) : this.id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'name': name,
      'dueDate': Timestamp.fromDate(dueDate),
      'value': value,
      'isPaid': isPaid,
      'isRecurring': isRecurring,
      'recurringDayOfMonth': recurringDayOfMonth,
      'lastPaidDate':
          lastPaidDate != null ? Timestamp.fromDate(lastPaidDate!) : null,
    };
  }

  factory Account.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Dados nulos para o documento Account: ${snapshot.id}');
    }
    return Account(
      id: snapshot.id,
      categoryId: data['categoryId'] as String? ?? '',
      name: data['name'] as String? ?? 'Conta Sem Nome',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      value: (data['value'] as num?)?.toDouble(),
      isPaid: data['isPaid'] as bool? ?? false,
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurringDayOfMonth: data['recurringDayOfMonth'] as int?,
      lastPaidDate: (data['lastPaidDate'] as Timestamp?)?.toDate(),
    );
  }

  Account copyWith({
    String? id,
    String? categoryId,
    String? name,
    DateTime? dueDate,
    double? value,
    bool? isPaid,
    bool? isRecurring,
    int? recurringDayOfMonth,
    DateTime? lastPaidDate,
    bool createPaidInstance = false,
    DateTime? occurrenceDueDate,
  }) {
    if (createPaidInstance && occurrenceDueDate != null) {
      return Account(
        id: uuid.v4(),
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        dueDate: occurrenceDueDate,
        value: value ?? this.value,
        isPaid: true,
        isRecurring: false,
        recurringDayOfMonth: null,
        lastPaidDate: null,
      );
    }
    return Account(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      dueDate: dueDate ?? this.dueDate,
      value: value ?? this.value,
      isPaid: isPaid ?? this.isPaid,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDayOfMonth: recurringDayOfMonth ?? this.recurringDayOfMonth,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
    );
  }

  DateTime? get nextPotentialDueDateForRecurringMolde {
    if (!isRecurring || recurringDayOfMonth == null) {
      return null;
    }
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime referenceDate = lastPaidDate ?? dueDate;
    int year = referenceDate.year;
    int month = referenceDate.month;

    if (lastPaidDate != null &&
        (lastPaidDate!.year > year ||
            (lastPaidDate!.year == year && lastPaidDate!.month > month) ||
            (lastPaidDate!.year == year &&
                lastPaidDate!.month == month &&
                lastPaidDate!.day >= recurringDayOfMonth!))) {
      month = lastPaidDate!.month + 1;
      if (month > 12) {
        month = 1;
        year = lastPaidDate!.year + 1;
      } else {
        year = lastPaidDate!.year;
      }
    } else if (lastPaidDate == null) {
      DateTime firstPossibleInCurrentMonth = DateTime(
        year,
        month,
        recurringDayOfMonth!,
      );
      if (firstPossibleInCurrentMonth.isBefore(today)) {
        month = now.month; // Start from current month
        year = now.year;
        DateTime potentialThisMonth = DateTime(
          year,
          month,
          recurringDayOfMonth!,
        );
        if (potentialThisMonth.isBefore(today)) {
          month++;
          if (month > 12) {
            month = 1;
            year++;
          }
        }
      } else {
        // If first occurrence is today or in the future, use its month and year
        month = firstPossibleInCurrentMonth.month;
        year = firstPossibleInCurrentMonth.year;
      }
    }

    try {
      return DateTime(year, month, recurringDayOfMonth!);
    } catch (e) {
      // Handle invalid date (e.g., day 31 in a month with 30 days)
      // Go to the last day of that month, then calculate next.
      // This is a simplification; robust date logic can be complex.
      try {
        return DateTime(year, month + 1, 0); // Last day of the intended month
      } catch (e2) {
        return null; // Should not happen if year/month logic is correct
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.name == name &&
        other.dueDate == dueDate &&
        other.value == value &&
        other.isPaid == isPaid &&
        other.isRecurring == isRecurring &&
        other.recurringDayOfMonth == recurringDayOfMonth &&
        other.lastPaidDate == lastPaidDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        categoryId.hashCode ^
        name.hashCode ^
        dueDate.hashCode ^
        value.hashCode ^
        isPaid.hashCode ^
        isRecurring.hashCode ^
        recurringDayOfMonth.hashCode ^
        lastPaidDate.hashCode;
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, dueDate: ${dueDate.toIso8601String()}, value: $value, isPaid: $isPaid, isRecurring: $isRecurring, recDay: $recurringDayOfMonth, lastPaid: ${lastPaidDate?.toIso8601String()})';
  }
}
