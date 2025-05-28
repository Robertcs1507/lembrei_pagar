// lib/models/account.dart
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

var uuid = Uuid();

class Account {
  final String id;
  final String categoryId;
  String name;
  DateTime dueDate;
  double? value;
  bool isPaid;
  String? userId; // <<< CAMPO ADICIONADO
  DateTime? createdAt; // <<< CAMPO ADICIONADO

  // Campos para Recorrência
  bool isRecurring;
  int? recurringDayOfMonth;
  DateTime? lastPaidDate;

  Account({
    String? id,
    required this.categoryId,
    required this.name,
    required this.dueDate,
    this.value,
    this.isPaid = false,
    this.userId, // <<< ADICIONADO AO CONSTRUTOR
    this.createdAt, // <<< ADICIONADO AO CONSTRUTOR
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
      'userId': userId, // <<< ADICIONADO AO MAPA
      'createdAt':
          createdAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(
                createdAt!,
              ), // Define na criação, mantém em atualizações
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
      userId: data['userId'] as String?, // <<< LENDO DO FIRESTORE
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate(), // <<< LENDO DO FIRESTORE
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
    String? userId, // <<< ADICIONADO
    DateTime? createdAt, // <<< ADICIONADO
    bool? isRecurring,
    int? recurringDayOfMonth,
    DateTime? lastPaidDate,
    bool createPaidInstance = false,
    DateTime? occurrenceDueDate,
  }) {
    if (createPaidInstance && occurrenceDueDate != null) {
      return Account(
        id: uuid.v4(), // Novo ID para a instância paga
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        dueDate: occurrenceDueDate,
        value: value ?? this.value,
        isPaid: true,
        userId: userId ?? this.userId, // Mantém o userId original
        createdAt: DateTime.now(), // Nova instância, novo createdAt
        isRecurring: false, // Instância paga não é o molde recorrente
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
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
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

    if (lastPaidDate != null) {
      if (referenceDate.day >= recurringDayOfMonth!) {
        month = referenceDate.month + 1;
        if (month > 12) {
          month = 1;
          year = referenceDate.year + 1;
        } else {
          year = referenceDate.year;
        }
      } else {
        month = referenceDate.month;
        year = referenceDate.year;
      }
    } else {
      DateTime potentialDueDateInCurrentCycle = DateTime(
        year,
        month,
        recurringDayOfMonth!,
      );
      if (potentialDueDateInCurrentCycle.isBefore(today) ||
          (potentialDueDateInCurrentCycle.isAtSameMomentAs(today) && isPaid)) {
        month = month + 1;
        if (month > 12) {
          month = 1;
          year = year + 1;
        }
      }
    }

    try {
      return DateTime(year, month, recurringDayOfMonth!);
    } catch (e) {
      // print("Erro ao calcular nextPotentialDueDateForRecurringMolde (dia inválido): $year-$month-$recurringDayOfMonth");
      // Tenta retornar o último dia do mês calculado se o dia recorrente for maior que o último dia do mês
      if (recurringDayOfMonth! > 28) {
        try {
          DateTime lastDayOfMonth = DateTime(
            year,
            month + 1,
            0,
          ); // Último dia do mês 'month'
          if (lastDayOfMonth.day < recurringDayOfMonth!) {
            return lastDayOfMonth;
          }
        } catch (e2) {
          // Se até mesmo calcular o último dia do mês falhar (ex: mês inválido), retorne null
          // print("Erro ao calcular último dia do mês em nextPotentialDueDateForRecurringMolde: $e2");
          return null;
        }
      }
      return null; // Retorna null se não puder construir uma data válida
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
        other.userId == userId && // <<< ADICIONADO
        other.createdAt == createdAt && // <<< ADICIONADO
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
        userId.hashCode ^ // <<< ADICIONADO
        createdAt.hashCode ^ // <<< ADICIONADO
        isRecurring.hashCode ^
        recurringDayOfMonth.hashCode ^
        lastPaidDate.hashCode;
  }

  @override
  String toString() {
    return 'Account(id: $id, categoryId: $categoryId, name: $name, dueDate: ${dueDate.toIso8601String()}, value: $value, isPaid: $isPaid, userId: $userId, createdAt: ${createdAt?.toIso8601String()}, isRecurring: $isRecurring, recurringDayOfMonth: $recurringDayOfMonth, lastPaidDate: ${lastPaidDate?.toIso8601String()})';
  }
}
