// lib/screens/category_accounts_page.dart
import 'dart:io'; // Para Platform.isAndroid
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/category.dart' as app_models;
import '../models/account.dart'; // Seu modelo Account atualizado
import '../services/notification_service.dart'; // Para generateUniqueNotificationId e NotificationService()

var uuid = Uuid();

class CategoryAccountsPage extends StatefulWidget {
  final app_models.Category category;

  const CategoryAccountsPage({Key? key, required this.category})
    : super(key: key);

  @override
  _CategoryAccountsPageState createState() => _CategoryAccountsPageState();
}

class _CategoryAccountsPageState extends State<CategoryAccountsPage> {
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountValueController = TextEditingController();
  final TextEditingController _recurringDayController = TextEditingController();
  bool _isRecurringDialog = false;
  DateTime _dialogSelectedDueDate = DateTime.now();

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountValueController.dispose();
    _recurringDayController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(
    BuildContext context, {
    DateTime? initialDate,
    required Function(DateTime) onDateSelected,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime firstSelectableDate = DateTime(now.year, now.month, now.day);
    DateTime datePickerInitialDate =
        initialDate != null && !initialDate.isBefore(firstSelectableDate)
            ? initialDate
            : firstSelectableDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: datePickerInitialDate,
      firstDate: firstSelectableDate,
      lastDate: DateTime(now.year + 10, now.month, now.day),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  // >>> FUNÇÃO DE AGENDAMENTO/CANCELAMENTO DE LEMBRETES <<<
  // Esta função agora recebe a conta e o status pago/não pago para decidir se agenda ou cancela
  Future<void> _scheduleOrCancelAccountNotifications(Account account) async {
    final String firestoreAccountId = account.id;
    debugPrint(
      "--- Iniciando Agendamento/Cancelamento de Lembretes para: ${account.name} (ID: $firestoreAccountId) ---",
    );

    // Sempre cancelar todas as notificações existentes para evitar duplicidade
    // ou notificações indesejadas após alteração de status/dados.
    // Para notif de 1 dia antes e HOJE (com sufixos específicos)
    await NotificationService().cancelNotification(
      generateUniqueNotificationId(
        firestoreAccountId,
        reminderTypeSuffix: "_1day_before",
      ),
    );
    await NotificationService().cancelNotification(
      generateUniqueNotificationId(
        firestoreAccountId,
        reminderTypeSuffix: "_due_date",
      ),
    );

    // Se você tiver outros sufixos de notificação, adicione-os aqui para cancelar
    // Ex: for (int daysBefore = 0; daysBefore <= 5; daysBefore++) { ... }
    // No seu Home, você tem múltiplos dias, então aqui também precisaria cancelar todos eles
    for (int daysBefore = 0; daysBefore <= 5; daysBefore++) {
      String suffix =
          (daysBefore == 0)
              ? "_due_today_9am"
              : "_${daysBefore}_days_before_9am";
      final int oldNotificationId = generateUniqueNotificationId(
        firestoreAccountId,
        reminderTypeSuffix: suffix,
      );
      await NotificationService().cancelNotification(oldNotificationId);
      debugPrint(
        "Tentativa de cancelamento para notificação com ID: $oldNotificationId (sufixo: $suffix)",
      );
    }

    // Se a conta NÃO está paga E NÃO é um molde recorrente (ou seja, é uma conta a vencer única),
    // agendar notificações. Para moldes recorrentes, o agendamento é feito na HomePage
    // ou quando a próxima instância é gerada.
    // IMPORTANTE: Para contas recorrentes que são o MOLDE, a notificação deve ser para o nextPotentialDueDateForRecurringMolde
    // Se account.isRecurring for TRUE (é um molde), só agenda se lastPaidDate indicar que a próxima está no futuro.
    // Se account.isRecurring for FALSE, agenda se não estiver paga e for futura.
    if (!account.isPaid) {
      // Se é um molde recorrente, agendamos para a próxima data calculada
      if (account.isRecurring) {
        DateTime? nextMoldeDueDate =
            account.nextPotentialDueDateForRecurringMolde;
        if (nextMoldeDueDate != null &&
            nextMoldeDueDate.isAfter(DateTime.now())) {
          // Reagenda as notificações para o molde recorrente
          _scheduleMoldeRecurringNotifications(
            account.copyWith(dueDate: nextMoldeDueDate),
          ); // Passa o molde com a próxima data de vencimento
        } else {
          debugPrint(
            "Molde recorrente '${account.name}' não será notificado agora (próxima data no passado ou nula).",
          );
        }
      } else {
        // Se é uma conta única (não recorrente) e não está paga, agenda as notificações diárias
        _scheduleDailyRemindersForSingleAccount(account);
      }
    } else {
      debugPrint(
        "Conta '${account.name}' está PAGA. Todas as notificações foram canceladas.",
      );
    }
    debugPrint(
      "--- Fim do Agendamento/Cancelamento de Lembretes para: ${account.name} ---",
    );
  }

  // Novo: Agendamento para contas ÚNICAS (não recorrentes)
  Future<void> _scheduleDailyRemindersForSingleAccount(Account account) async {
    final String firestoreAccountId = account.id;
    debugPrint(
      "Agendando lembretes diários para conta ÚNICA: ${account.name}...",
    );

    for (int daysBefore = 0; daysBefore <= 5; daysBefore++) {
      // 0 a 5 dias antes do vencimento
      DateTime notificationDay = account.dueDate.subtract(
        Duration(days: daysBefore),
      );
      DateTime scheduledDateTime = DateTime(
        notificationDay.year,
        notificationDay.month,
        notificationDay.day,
        9,
        0, // 09:00 AM
      );

      DateTime now = DateTime.now();
      if (scheduledDateTime.isAfter(now)) {
        String suffix =
            (daysBefore == 0)
                ? "_due_today_9am"
                : "_${daysBefore}_days_before_9am";
        final int newNotificationId = generateUniqueNotificationId(
          firestoreAccountId,
          reminderTypeSuffix: suffix,
        );
        String title;
        String body;
        String formattedDueDate = DateFormat(
          'dd/MM/yyyy',
        ).format(account.dueDate.toLocal());

        if (daysBefore == 0) {
          title = "ATENÇÃO: Conta Vence HOJE!";
          body =
              "Sua conta '${account.name}' vence HOJE ($formattedDueDate). Não se esqueça!";
        } else if (daysBefore == 1) {
          title = "Lembrete: Conta Vence AMANHÃ!";
          body =
              "Sua conta '${account.name}' vence AMANHÃ ($formattedDueDate). Prepare-se!";
        } else {
          title = "Lembrete: Conta Vence em $daysBefore Dias!";
          body =
              "Sua conta '${account.name}' vence em $daysBefore dias ($formattedDueDate). Não se esqueça!";
        }

        debugPrint(
          "AGENDANDO: Notif ID $newNotificationId, Data/Hora: $scheduledDateTime, Título: $title",
        );
        await NotificationService().scheduleNotification(
          id: newNotificationId,
          title: title,
          body: body,
          scheduledDateTime: scheduledDateTime,
          payload: firestoreAccountId,
        );
      } else {
        debugPrint(
          "NÃO AGENDADO (data passada): ${account.name} (Dias antes: $daysBefore). Agora: $now",
        );
      }
    }
  }

  // Novo: Agendamento para Moldes RECORRENTES (próxima ocorrência)
  Future<void> _scheduleMoldeRecurringNotifications(Account molde) async {
    final String firestoreAccountId = molde.id;
    debugPrint("Agendando lembretes para MOLDE RECORRENTE: ${molde.name}...");

    DateTime? nextDueDate = molde.nextPotentialDueDateForRecurringMolde;
    if (nextDueDate == null || !nextDueDate.isAfter(DateTime.now())) {
      debugPrint(
        "Próxima data de vencimento do molde recorrente '${molde.name}' não é válida ou já passou. Nenhuma notificação agendada.",
      );
      return;
    }

    // Agendar 1 dia antes
    DateTime oneDayBefore = nextDueDate.subtract(const Duration(days: 1));
    DateTime scheduledOneDayBefore = DateTime(
      oneDayBefore.year,
      oneDayBefore.month,
      oneDayBefore.day,
      9,
      0,
    );
    if (scheduledOneDayBefore.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: generateUniqueNotificationId(
          molde.id,
          reminderTypeSuffix: "_1day_before",
        ),
        title: 'Lembrete Recorrente: Vence Amanhã!',
        body:
            'Sua conta mensal "${molde.name}" vence amanhã, ${DateFormat('dd/MM/yyyy').format(nextDueDate.toLocal())}!',
        scheduledDateTime: scheduledOneDayBefore,
        payload: molde.id,
      );
      debugPrint("Agendado: Molde '${molde.name}' 1 dia antes.");
    }

    // Agendar para o dia do vencimento
    DateTime scheduledOnDueDate = DateTime(
      nextDueDate.year,
      nextDueDate.month,
      nextDueDate.day,
      9,
      0,
    );
    if (scheduledOnDueDate.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: generateUniqueNotificationId(
          molde.id,
          reminderTypeSuffix: "_due_date",
        ),
        title: 'CONTA MENSAL VENCE HOJE!',
        body:
            'Sua conta mensal "${molde.name}" vence hoje, ${DateFormat('dd/MM/yyyy').format(nextDueDate.toLocal())}!',
        scheduledDateTime: scheduledOnDueDate,
        payload: molde.id,
      );
      debugPrint("Agendado: Molde '${molde.name}' no dia do vencimento.");
    }
  }

  void _showAddAccountDialog() {
    _accountNameController.clear();
    _accountValueController.clear();
    _recurringDayController.clear();
    _isRecurringDialog = false;
    _dialogSelectedDueDate = DateTime.now();
    showDialog(
      context: context,
      builder: (BuildContext dialogPopupContext) {
        return AlertDialog(
          title: const Text('Nova Conta'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Conta',
                      ),
                    ),
                    TextField(
                      controller: _accountValueController,
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$)',
                        hintText: 'Ex: 150.75',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Vencimento: ${DateFormat('dd/MM/yyyy').format(_dialogSelectedDueDate.toLocal())}',
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => _selectDueDate(
                                context,
                                initialDate: _dialogSelectedDueDate,
                                onDateSelected: (pickedDate) {
                                  setStateDialog(() {
                                    _dialogSelectedDueDate = pickedDate;
                                    if (_isRecurringDialog) {
                                      _recurringDayController.text =
                                          pickedDate.day.toString();
                                    }
                                  });
                                },
                              ),
                          child: const Text('Selecionar'),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text(
                        "Conta Mensal?",
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _isRecurringDialog,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          _isRecurringDialog = value ?? false;
                          if (_isRecurringDialog) {
                            _recurringDayController.text =
                                _dialogSelectedDueDate.day.toString();
                          } else {
                            _recurringDayController.clear();
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_isRecurringDialog)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextField(
                          controller: _recurringDayController,
                          decoration: const InputDecoration(
                            labelText: 'Dia do Venc. Mensal',
                            hintText: 'Ex: 10 (1-31)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogPopupContext).pop(),
            ),
            TextButton(
              child: const Text('Adicionar'),
              onPressed: () async {
                if (_accountNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, insira um nome para a conta.'),
                    ),
                  );
                  return;
                }
                int? recurringDay;
                if (_isRecurringDialog) {
                  if (_recurringDayController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, insira o dia do vencimento mensal.',
                        ),
                      ),
                    );
                    return;
                  }
                  recurringDay = int.tryParse(
                    _recurringDayController.text.trim(),
                  );
                  if (recurringDay == null ||
                      recurringDay < 1 ||
                      recurringDay > 31) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      const SnackBar(
                        content: Text('Dia do vencimento mensal inválido.'),
                      ),
                    );
                    return;
                  }
                }

                DateTime effectiveDueDateForSave = _dialogSelectedDueDate;
                if (_isRecurringDialog && recurringDay != null) {
                  // Ao criar um molde, a dueDate inicial deve ser a do primeiro ciclo válido.
                  // Se o dia recorrente já passou no mês da data selecionada, avança para o próximo mês.
                  DateTime potentialDateThisMonth = DateTime(
                    _dialogSelectedDueDate.year,
                    _dialogSelectedDueDate.month,
                    recurringDay,
                  );
                  if (potentialDateThisMonth.isBefore(DateTime.now()) &&
                      _dialogSelectedDueDate.month == DateTime.now().month &&
                      _dialogSelectedDueDate.year == DateTime.now().year) {
                    effectiveDueDateForSave = DateTime(
                      _dialogSelectedDueDate.year,
                      _dialogSelectedDueDate.month +
                          1, // Avança para o próximo mês
                      recurringDay,
                    );
                  } else {
                    effectiveDueDateForSave = potentialDateThisMonth;
                  }
                }

                User? currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) {
                  print("Erro: Usuário não logado.");
                  if (mounted) Navigator.of(dialogPopupContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro: Você precisa estar logado.'),
                    ),
                  );
                  return;
                }
                String userId = currentUser.uid;

                final accountToSave = Account(
                  categoryId: widget.category.id,
                  name: _accountNameController.text.trim(),
                  dueDate:
                      effectiveDueDateForSave, // Data de vencimento inicial
                  value:
                      _accountValueController.text.trim().isEmpty
                          ? null
                          : double.tryParse(
                            _accountValueController.text.trim().replaceAll(
                              ',',
                              '.',
                            ),
                          ),
                  isPaid: false, // Nova conta nunca começa como paga
                  userId: userId,
                  createdAt: null, // Será definido pelo serverTimestamp()
                  isRecurring: _isRecurringDialog,
                  recurringDayOfMonth: recurringDay,
                  lastPaidDate:
                      null, // Nova conta recorrente não tem último pagamento
                  paidDate: null, // Nova conta não foi paga ainda
                );

                try {
                  DocumentReference docRef = await FirebaseFirestore.instance
                      .collection('accounts')
                      .add(accountToSave.toFirestore());
                  String firestoreAccountId = docRef.id;
                  print(
                    "Conta adicionada com ID: $firestoreAccountId e userId: $userId",
                  );

                  if (mounted) Navigator.of(dialogPopupContext).pop();

                  // Agendar lembretes para a nova conta
                  await _scheduleOrCancelAccountNotifications(
                    accountToSave.copyWith(id: firestoreAccountId),
                  );
                } catch (e) {
                  print('Erro ao adicionar conta: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      SnackBar(content: Text('Erro ao adicionar conta: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditAccountDialog(Account accountToEditOriginal) {
    // É importante criar uma cópia mutável para editar no diálogo,
    // pois 'accountToEditOriginal' é final.
    Account accountToEdit = accountToEditOriginal.copyWith();

    _accountNameController.text = accountToEdit.name;
    _accountValueController.text =
        accountToEdit.value?.toString().replaceAll('.', ',') ?? '';
    _dialogSelectedDueDate = accountToEdit.dueDate;
    _isRecurringDialog = accountToEdit.isRecurring;
    _recurringDayController.text =
        accountToEdit.recurringDayOfMonth?.toString() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext dialogPopupContext) {
        return AlertDialog(
          title: const Text('Editar Conta'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialogInEdit) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Conta',
                      ),
                    ),
                    TextField(
                      controller: _accountValueController,
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$)',
                        hintText: 'Ex: 150,75',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Vencimento: ${DateFormat('dd/MM/yyyy').format(_dialogSelectedDueDate.toLocal())}',
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => _selectDueDate(
                                context,
                                initialDate: _dialogSelectedDueDate,
                                onDateSelected: (pickedDate) {
                                  setStateDialogInEdit(() {
                                    _dialogSelectedDueDate = pickedDate;
                                    if (_isRecurringDialog) {
                                      _recurringDayController.text =
                                          pickedDate.day.toString();
                                    }
                                  });
                                },
                              ),
                          child: const Text('Selecionar'),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text(
                        "Conta Mensal?",
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _isRecurringDialog,
                      onChanged: (bool? value) {
                        setStateDialogInEdit(() {
                          _isRecurringDialog = value ?? false;
                          if (_isRecurringDialog) {
                            if (_recurringDayController.text.isEmpty) {
                              _recurringDayController.text =
                                  _dialogSelectedDueDate.day.toString();
                            }
                          } else {
                            _recurringDayController.clear();
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_isRecurringDialog)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextField(
                          controller: _recurringDayController,
                          decoration: const InputDecoration(
                            labelText: 'Dia do Venc. Mensal',
                            hintText: 'Ex: 10 (1-31)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogPopupContext).pop(),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () async {
                if (_accountNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, insira um nome para a conta.'),
                    ),
                  );
                  return;
                }
                int? recurringDay;
                DateTime effectiveDueDate = _dialogSelectedDueDate;

                if (_isRecurringDialog) {
                  if (_recurringDayController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, insira o dia do vencimento mensal.',
                        ),
                      ),
                    );
                    return;
                  }
                  recurringDay = int.tryParse(
                    _recurringDayController.text.trim(),
                  );
                  if (recurringDay == null ||
                      recurringDay < 1 ||
                      recurringDay > 31) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      const SnackBar(
                        content: Text('Dia do vencimento mensal inválido.'),
                      ),
                    );
                    return;
                  }
                  effectiveDueDate = DateTime(
                    _dialogSelectedDueDate.year,
                    _dialogSelectedDueDate.month,
                    recurringDay,
                  );
                }

                Account updatedAccountData = accountToEdit.copyWith(
                  name: _accountNameController.text.trim(),
                  dueDate: effectiveDueDate,
                  value:
                      _accountValueController.text.trim().isEmpty
                          ? null
                          : double.tryParse(
                            _accountValueController.text.trim().replaceAll(
                              ',',
                              '.',
                            ),
                          ),
                  isRecurring: _isRecurringDialog,
                  recurringDayOfMonth: _isRecurringDialog ? recurringDay : null,
                  // Se a conta for alterada para não recorrente, e estava paga,
                  // ou se a data mudou para o futuro, etc.
                  // Seu paidDate deve ser resetado se ela se tornar 'não paga'
                  isPaid: accountToEdit.isPaid, // Mantém o status pago/não pago
                  paidDate:
                      accountToEdit.paidDate, // Mantém a data de pagamento
                );

                try {
                  Map<String, dynamic> dataToUpdate = {
                    'name': updatedAccountData.name,
                    'dueDate': Timestamp.fromDate(updatedAccountData.dueDate),
                    'value': updatedAccountData.value,
                    'isRecurring': updatedAccountData.isRecurring,
                    'recurringDayOfMonth':
                        updatedAccountData.recurringDayOfMonth,
                    // Garante que paidDate e isPaid não sejam perdidos ou sobrescritos aqui,
                    // a menos que haja uma lógica específica de edição.
                    'isPaid': updatedAccountData.isPaid,
                    'paidDate':
                        updatedAccountData.paidDate != null
                            ? Timestamp.fromDate(updatedAccountData.paidDate!)
                            : null,
                  };

                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountToEdit.id)
                      .update(dataToUpdate);

                  print("Conta ${accountToEdit.id} atualizada.");
                  if (mounted) Navigator.of(dialogPopupContext).pop();

                  // Reagendar lembretes para a conta atualizada
                  await _scheduleOrCancelAccountNotifications(
                    updatedAccountData,
                  );
                } catch (e) {
                  print('Erro ao atualizar conta: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      SnackBar(content: Text('Erro ao atualizar conta: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Função _showAccountOptions: Onde a lógica de marcar como paga está ---
  void _showAccountOptions(Account account) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar Conta'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showEditAccountDialog(account);
                },
              ),
              ListTile(
                leading: Icon(
                  account.isPaid
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                title: Text(
                  account.isPaid ? 'Marcar como Não Paga' : 'Marcar como Paga',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);

                  // Se a conta for marcada como PAGA
                  if (!account.isPaid) {
                    if (account.isRecurring) {
                      // Se for recorrente e marcada como paga:
                      // 1. Cria uma NOVA instância paga (única)
                      DateTime? nextDueDateForInstance =
                          account.nextPotentialDueDateForRecurringMolde;
                      if (nextDueDateForInstance == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Erro: Não foi possível calcular a próxima data para a recorrência.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      Account newPaidInstance = Account(
                        categoryId: account.categoryId,
                        name: account.name,
                        dueDate:
                            account
                                .dueDate, // Mantém a dueDate do molde para a instância
                        value: account.value,
                        isPaid: true,
                        userId: account.userId,
                        createdAt:
                            DateTime.now(), // Data de criação da instância
                        isRecurring: false, // Instância paga é única
                        recurringDayOfMonth: null,
                        lastPaidDate: null,
                        paidDate:
                            DateTime.now(), // Data em que esta instância foi paga
                      );

                      DocumentReference newDocRef = await FirebaseFirestore
                          .instance
                          .collection('accounts')
                          .add(newPaidInstance.toFirestore());
                      print(
                        "Nova instância recorrente paga criada com ID: ${newDocRef.id}",
                      );

                      // 2. Atualiza o MOLDE ORIGINAL recorrente
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(account.id)
                          .update({
                            'lastPaidDate': Timestamp.fromDate(
                              newPaidInstance.paidDate!,
                            ), // Atualiza o último pagamento do molde
                            // Garante que o molde original NÃO seja marcado como isPaid: true aqui
                            // ou que sua dueDate base reflita o próximo ciclo se for a lógica.
                            // Para moldes, geralmente isPaid permanece false.
                            // 'isPaid': false, // O molde recorrente principal não é "pago"
                          });

                      // Agendar notificações para a PRÓXIMA ocorrência do MOLDE ORIGINAL
                      await _scheduleOrCancelAccountNotifications(
                        account,
                      ); // Passa o molde original para reagendar

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Conta recorrente "${account.name}" marcada como paga e próxima instância criada.',
                            ),
                          ),
                        );
                      }
                    } else {
                      // Se for uma conta única (não recorrente) e marcada como paga:
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(account.id)
                          .update({
                            'isPaid': true,
                            'paidDate': Timestamp.fromDate(
                              DateTime.now(),
                            ), // Define paidDate para contas únicas
                          });
                      print("Conta ${account.name} marcada como paga.");
                      await _scheduleOrCancelAccountNotifications(
                        account.copyWith(isPaid: true),
                      ); // Cancela as notificações
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Conta "${account.name}" marcada como paga.',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    // Se a conta for marcada como NÃO PAGA (reverte o status)
                    // (Isso só deve acontecer para contas ÚNICAS que foram acidentalmente marcadas como pagas)
                    if (account.isRecurring) {
                      // Não deveria ser possível "despagar" um molde recorrente dessa forma.
                      // Se for uma instância paga de um recorrente, essa instância não aparece aqui.
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não é possível desmarcar uma conta recorrente como não paga diretamente.',
                            ),
                          ),
                        );
                      }
                      return;
                    } else {
                      // Se for uma conta única e marcada como não paga
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(account.id)
                          .update({
                            'isPaid': false,
                            'paidDate': null, // Limpa paidDate
                          });
                      print("Conta ${account.name} marcada como não paga.");
                      await _scheduleOrCancelAccountNotifications(
                        account.copyWith(isPaid: false),
                      ); // Reagenda notificações
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Conta "${account.name}" marcada como não paga.',
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Excluir Conta'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showDeleteAccountDialog(account);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(Account account) {
    showDialog(
      context: context,
      builder: (BuildContext dialogPopupContext) {
        return AlertDialog(
          title: const Text('Excluir Conta'),
          content: Text(
            'Tem certeza que deseja excluir a conta "${account.name}"?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogPopupContext).pop(),
            ),
            TextButton(
              child: const Text('Excluir'),
              onPressed: () async {
                try {
                  String accountId = account.id;

                  // Cancela todas as notificações relacionadas a esta conta antes de excluí-la
                  await _scheduleOrCancelAccountNotifications(
                    account.copyWith(isPaid: true),
                  ); // Passa como paga para cancelar tudo

                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountId)
                      .delete();
                  print("Conta $accountId excluída.");
                  if (mounted) Navigator.of(dialogPopupContext).pop();
                } catch (e) {
                  print("Erro ao excluir conta: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(dialogPopupContext).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir conta: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            currentUserId == null
                ? Stream.empty()
                : FirebaseFirestore.instance
                    .collection('accounts')
                    .where('categoryId', isEqualTo: widget.category.id)
                    .where('userId', isEqualTo: currentUserId)
                    // Ordena por isPaid primeiro (não pagas no topo), depois por dueDate
                    .orderBy('isPaid')
                    .orderBy('dueDate')
                    .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (currentUserId == null) {
            return const Center(
              child: Text('Faça login para ver suas contas.'),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final accountsFromFirestore = snapshot.data?.docs;
          if (accountsFromFirestore == null || accountsFromFirestore.isEmpty) {
            return const Center(
              child: Text('Você não tem contas nesta categoria.'),
            );
          }

          // Filtrar as contas para exibir:
          // Apenas contas não pagas E os moldes recorrentes (isRecurring: true)
          // Isso evita que instâncias pagas (que são isPaid:true, isRecurring:false) apareçam na lista principal
          final List<Account> accountsToShow =
              accountsFromFirestore
                  .map((doc) => Account.fromFirestore(doc))
                  .where(
                    (account) =>
                        !account.isPaid || // Exibe contas que não estão pagas
                        (account.isRecurring &&
                            !account
                                .isPaid), // Exibe moldes recorrentes que não foram pagos ainda (se a dueDate base não os marca como 'pago')
                  )
                  .toList();

          // Se a conta já está paga e não é recorrente (é uma instância paga), ela não deve aparecer nessa lista
          // Isso garante que você veja apenas o MOLDE da recorrente, e não as instâncias pagas aqui.
          accountsToShow.removeWhere(
            (account) => account.isPaid && !account.isRecurring,
          );

          if (accountsToShow.isEmpty) {
            return const Center(
              child: Text('Nenhuma conta a vencer nesta categoria.'),
            );
          }

          return ListView.builder(
            itemCount: accountsToShow.length,
            itemBuilder: (context, index) {
              try {
                final Account account =
                    accountsToShow[index]; // Use a lista filtrada

                String subtitleText =
                    'Vencimento: ${DateFormat('dd/MM/yyyy').format(account.dueDate.toLocal())}';
                if (account.value != null) {
                  subtitleText +=
                      ' - R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '').format(account.value ?? 0.0)}';
                }

                Color itemColor = Colors.transparent;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final dueDateDayOnly = DateTime(
                  account.dueDate.year,
                  account.dueDate.month,
                  account.dueDate.day,
                );

                // Lógica de cor para contas a vencer
                if (!account.isPaid) {
                  if (dueDateDayOnly.isAtSameMomentAs(today)) {
                    itemColor = Colors.red.withOpacity(0.3); // Vence hoje
                  } else if (dueDateDayOnly.isBefore(today)) {
                    itemColor = Colors.grey.withOpacity(0.3); // Atrasada
                  }
                }
                // Se a conta está paga, mas não é recorrente, ela não deveria estar aqui devido ao filtro.
                // Se é recorrente e está paga, também não deveria estar aqui (o molde não fica pago).

                String statusText = "";
                // Status para contas exibidas na CategoryAccountsPage (a vencer ou moldes recorrentes)
                if (account.isRecurring) {
                  if (account.lastPaidDate != null) {
                    statusText =
                        ' (Últ. Pgto: ${DateFormat('dd/MM/yyyy').format(account.lastPaidDate!.toLocal())})';
                  } else {
                    statusText = " (Mensal)"; // Se recorrente e nunca paga
                  }
                } else if (account.isPaid) {
                  // Esta condição só deve ser alcançada se uma conta única paga for exibida por algum motivo,
                  // mas a intenção é que contas pagas únicas não apareçam aqui.
                  statusText = ' (PAGO)';
                  itemColor = Colors.green.withOpacity(
                    0.3,
                  ); // Cor verde para pago
                }

                return Card(
                  color: itemColor,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(account.name + statusText),
                    subtitle: Text(subtitleText),
                    leading: Icon(
                      // Ícone para contas recorrentes ou a vencer
                      account.isRecurring ? Icons.repeat : Icons.event_note,
                      color:
                          account.isRecurring ? Colors.orange : Colors.blueGrey,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showAccountOptions(account),
                    ),
                  ),
                );
              } catch (e, s) {
                print('Erro ao processar item de conta: $e\n$s');
                return ListTile(title: Text('Erro no item $index'));
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        tooltip: 'Adicionar Conta',
        child: const Icon(Icons.add),
      ),
    );
  }
}
