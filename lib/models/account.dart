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
  String? userId;
  DateTime? createdAt;

  // Campos para Recorrência
  bool isRecurring;
  int? recurringDayOfMonth;
  DateTime? lastPaidDate;

  // NOVO CAMPO: Data em que esta instância específica da conta foi marcada como paga
  DateTime? paidDate;

  Account({
    String? id,
    required this.categoryId,
    required this.name,
    required this.dueDate,
    this.value,
    this.isPaid = false,
    this.userId,
    this.createdAt,
    this.isRecurring = false,
    this.recurringDayOfMonth,
    this.lastPaidDate,
    this.paidDate, // <<< ADICIONADO AQUI NO CONSTRUTOR
  }) : this.id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'name': name,
      'dueDate': Timestamp.fromDate(dueDate),
      'value': value,
      'isPaid': isPaid,
      'userId': userId,
      'createdAt':
          createdAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(createdAt!),
      'isRecurring': isRecurring,
      'recurringDayOfMonth': recurringDayOfMonth,
      'lastPaidDate':
          lastPaidDate != null ? Timestamp.fromDate(lastPaidDate!) : null,
      'paidDate':
          paidDate != null
              ? Timestamp.fromDate(paidDate!)
              : null, // <<< ADICIONADO AO MAPA
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
      userId: data['userId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurringDayOfMonth: data['recurringDayOfMonth'] as int?,
      lastPaidDate: (data['lastPaidDate'] as Timestamp?)?.toDate(),
      paidDate:
          (data['paidDate'] as Timestamp?)?.toDate(), // <<< LENDO DO FIRESTORE
    );
  }

  Account copyWith({
    String? id,
    String? categoryId,
    String? name,
    DateTime? dueDate,
    double? value,
    bool? isPaid,
    String? userId,
    DateTime? createdAt,
    bool? isRecurring,
    int? recurringDayOfMonth,
    DateTime? lastPaidDate,
    DateTime? paidDate, // <<< ADICIONADO AQUI NO copyWith
    bool createPaidInstance = false,
    DateTime? occurrenceDueDate, // A data de vencimento da instância específica
  }) {
    if (createPaidInstance) {
      // Criar uma nova instância paga para contas recorrentes
      return Account(
        id: uuid.v4(), // Novo ID para a instância paga
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        dueDate:
            occurrenceDueDate ??
            this.dueDate, // A data de vencimento da ocorrência atual
        value: value ?? this.value,
        isPaid: true,
        userId: userId ?? this.userId, // Mantém o userId original
        createdAt: DateTime.now(), // Nova instância, novo createdAt
        isRecurring:
            false, // Esta instância é uma conta paga única, não recorrente
        recurringDayOfMonth: null,
        lastPaidDate: null,
        paidDate:
            DateTime.now(), // <<< Define a data de pagamento para AGORA (para a nova instância paga)
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
      paidDate:
          paidDate ?? this.paidDate, // <<< ADICIONADO AQUI NO copyWith normal
    );
  }

  DateTime? get nextPotentialDueDateForRecurringMolde {
    if (!isRecurring || recurringDayOfMonth == null) {
      return null;
    }
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime referenceDate =
        lastPaidDate ?? dueDate; // Usa lastPaidDate se existir, senão dueDate

    int year = referenceDate.year;
    int month = referenceDate.month;

    // Se a conta recorrente já foi paga em um dia >= dia recorrente no mês de referência,
    // a próxima ocorrência deve ser no próximo mês.
    if (lastPaidDate != null && referenceDate.day >= recurringDayOfMonth!) {
      month = referenceDate.month + 1;
      if (month > 12) {
        month = 1;
        year = referenceDate.year + 1;
      }
    } else if (lastPaidDate == null) {
      // Se nunca foi paga e a dueDate (data base do molde) já passou no mês atual,
      // então a próxima é no mês seguinte.
      DateTime potentialDueDateInCurrentCycle = DateTime(
        year,
        month,
        recurringDayOfMonth!,
      );
      // Se o dia recorrente já passou neste mês E a conta não está marcada como paga (referindo-se ao molde),
      // ou se o dia é hoje e a conta JÁ foi paga (o que significa que a recorrência é para o próximo ciclo)
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
      // Retorna a data calculada, mas verifica se o dia é válido para o mês/ano
      // (Ex: dia 31 em fev)
      DateTime calculatedDate = DateTime(year, month, recurringDayOfMonth!);
      return calculatedDate;
    } catch (e) {
      // Se a data calculada (dia do mês) não for válida para o mês/ano (ex: 31 de fevereiro)
      // Tenta retornar o último dia do mês calculado se o dia recorrente for maior que o último dia do mês
      if (recurringDayOfMonth! > 28) {
        // Apenas para dias que podem causar problemas (29, 30, 31)
        try {
          DateTime lastDayOfMonth = DateTime(
            year,
            month + 1,
            0,
          ); // O dia 0 do próximo mês é o último dia do mês atual
          if (lastDayOfMonth.day < recurringDayOfMonth!) {
            return lastDayOfMonth; // Retorna o último dia válido do mês
          }
        } catch (e2) {
          // Fallback final se algo der muito errado
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
        other.userId == userId &&
        other.createdAt == createdAt &&
        other.isRecurring == isRecurring &&
        other.recurringDayOfMonth == recurringDayOfMonth &&
        other.lastPaidDate == lastPaidDate &&
        other.paidDate == paidDate; // <<< ADICIONADO AO OPERADOR ==
  }

  @override
  int get hashCode {
    return id.hashCode ^
        categoryId.hashCode ^
        name.hashCode ^
        dueDate.hashCode ^
        value.hashCode ^
        isPaid.hashCode ^
        userId.hashCode ^
        createdAt.hashCode ^
        isRecurring.hashCode ^
        recurringDayOfMonth.hashCode ^
        lastPaidDate.hashCode ^
        paidDate.hashCode; // <<< ADICIONADO AO HASHCODE
  }

  @override
  String toString() {
    return 'Account(id: $id, categoryId: $categoryId, name: $name, dueDate: ${dueDate.toIso8601String()}, value: $value, isPaid: $isPaid, userId: $userId, createdAt: ${createdAt?.toIso8601String()}, isRecurring: $isRecurring, recurringDayOfMonth: $recurringDayOfMonth, lastPaidDate: ${lastPaidDate?.toIso8601String()}, paidDate: ${paidDate?.toIso8601String()})';
  }
}
