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
// Se você não estiver usando AndroidAlarmManager para ESTES lembretes, pode remover os imports relacionados a ele
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// import '../services/alarm_callback_service.dart';

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

  // >>> NOVA FUNÇÃO PARA AGENDAR LEMBRETES DIÁRIOS <<<
  Future<void> _scheduleDailyRemindersUntilDueDate(Account account) async {
    final String firestoreAccountId = account.id;
    debugPrint(
      "--- Iniciando Agendamento/Cancelamento de Lembretes Diários para: ${account.name} (ID: $firestoreAccountId) ---",
    );

    // 1. Cancelar todas as 6 possíveis notificações antigas para esta conta
    for (int daysBefore = 0; daysBefore <= 5; daysBefore++) {
      // Inclui o dia do vencimento (0 dias antes) até 5 dias antes
      String suffix =
          (daysBefore == 0)
              ? "_due_today_9am" // Dia do vencimento
              : "_${daysBefore}_days_before_9am"; // Dias anteriores
      final int oldNotificationId = generateUniqueNotificationId(
        firestoreAccountId,
        reminderTypeSuffix: suffix,
      );
      await NotificationService().cancelNotification(oldNotificationId);
      debugPrint(
        "Tentativa de cancelamento para notificação com ID: $oldNotificationId (sufixo: $suffix)",
      );
    }

    // 2. Se a conta NÃO está paga, agendar as novas notificações
    if (!account.isPaid) {
      debugPrint("Conta NÃO está paga. Agendando novos lembretes diários...");

      for (int daysBefore = 0; daysBefore <= 5; daysBefore++) {
        DateTime notificationDay = account.dueDate.subtract(
          Duration(days: daysBefore),
        );
        DateTime scheduledDateTime = DateTime(
          notificationDay.year,
          notificationDay.month,
          notificationDay.day,
          9, // 09:00 AM
          0, // 00 minutos
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
            title = " ATENÇÃO: Conta Vence HOJE!";
            body =
                "Sua conta '${account.name}' vence HOJE ($formattedDueDate). Não se esqueça!";
          } else if (daysBefore == 1) {
            title = " Lembrete: Conta Vence AMANHÃ!";
            body =
                "Sua conta '${account.name}' vence AMANHÃ ($formattedDueDate). Prepare-se!";
          } else {
            title = " Lembrete: Conta Vence em $daysBefore Dias!";
            body =
                "Sua conta '${account.name}' vence em $daysBefore dias ($formattedDueDate). Não se esqueça!";
          }

          debugPrint(
            "AGENDANDO para ${account.name}: Notif ID $newNotificationId, Data/Hora: $scheduledDateTime, Título: $title",
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
            "NÃO AGENDADO para ${account.name}: Data ${scheduledDateTime} já passou (Dias antes: $daysBefore). Agora: $now",
          );
        }
      }
    } else {
      debugPrint(
        "Conta '${account.name}' está PAGA. Todas as 6 possíveis notificações foram canceladas.",
      );
    }
    debugPrint(
      "--- Fim do Agendamento/Cancelamento de Lembretes Diários para: ${account.name} ---",
    );
  }

  void _showAddAccountDialog() {
    // ... (seu código _showAddAccountDialog existente, mas no onPressed de 'Adicionar', chame a nova função)
    // Cole seu código do diálogo aqui, e eu mostrarei a modificação no onPressed.
    // Por enquanto, vou colocar o trecho modificado do onPressed:
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
                // ... (sua lógica de validação existente)
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
                  DateTime now = DateTime.now();
                  DateTime potentialDate = DateTime(
                    _dialogSelectedDueDate.year,
                    _dialogSelectedDueDate.month,
                    recurringDay,
                  );
                  if (potentialDate.isBefore(_dialogSelectedDueDate) &&
                      potentialDate.day < _dialogSelectedDueDate.day &&
                      _dialogSelectedDueDate.month == potentialDate.month) {
                    effectiveDueDateForSave = DateTime(
                      _dialogSelectedDueDate.year,
                      _dialogSelectedDueDate.month + 1,
                      recurringDay,
                    );
                  } else {
                    effectiveDueDateForSave = potentialDate;
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
                  dueDate: effectiveDueDateForSave,
                  value:
                      _accountValueController.text.trim().isEmpty
                          ? null
                          : double.tryParse(
                            _accountValueController.text.trim().replaceAll(
                              ',',
                              '.',
                            ),
                          ),
                  isPaid: false,
                  userId: userId,
                  createdAt: null,
                  isRecurring: _isRecurringDialog,
                  recurringDayOfMonth: recurringDay,
                  lastPaidDate: null,
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

                  // <<< CHAMAR A NOVA FUNÇÃO DE AGENDAMENTO >>>
                  await _scheduleDailyRemindersUntilDueDate(
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
    // ... (seu código _showEditAccountDialog existente, mas no onPressed de 'Salvar', chame a nova função)
    // Cole seu código do diálogo aqui, e eu mostrarei a modificação no onPressed.
    // Por enquanto, vou colocar o trecho modificado do onPressed:
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
                // ... (sua lógica de validação)
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
                );

                try {
                  Map<String, dynamic> dataToUpdate = {
                    'name': updatedAccountData.name,
                    'dueDate': Timestamp.fromDate(updatedAccountData.dueDate),
                    'value': updatedAccountData.value,
                    'isRecurring': updatedAccountData.isRecurring,
                    'recurringDayOfMonth':
                        updatedAccountData.recurringDayOfMonth,
                  };

                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountToEdit.id)
                      .update(dataToUpdate);

                  print("Conta ${accountToEdit.id} atualizada.");
                  if (mounted) Navigator.of(dialogPopupContext).pop();

                  // <<< CHAMAR A NOVA FUNÇÃO DE AGENDAMENTO >>>
                  await _scheduleDailyRemindersUntilDueDate(updatedAccountData);
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
                  Account updatedAccount = account.copyWith(
                    isPaid: !account.isPaid,
                  );

                  if (updatedAccount.isPaid && updatedAccount.isRecurring) {
                    DateTime? nextDueDate =
                        updatedAccount.nextPotentialDueDateForRecurringMolde;
                    if (nextDueDate != null) {
                      Account nextRecurringInstance = updatedAccount.copyWith(
                        id: uuid.v4(),
                        isPaid: false,
                        dueDate: nextDueDate,
                        lastPaidDate: account.dueDate,
                        createdAt: null,
                      );
                      // Salvar a nova instância recorrente
                      DocumentReference newDocRef = await FirebaseFirestore
                          .instance
                          .collection('accounts')
                          .add(nextRecurringInstance.toFirestore());
                      print(
                        "Próxima ocorrência recorrente criada para ${nextRecurringInstance.name} com ID: ${newDocRef.id}",
                      );
                      // Agendar para a nova instância
                      await _scheduleDailyRemindersUntilDueDate(
                        nextRecurringInstance.copyWith(id: newDocRef.id),
                      );

                      // Marcar a instância atual como paga e não mais o "molde" da recorrência principal
                      updatedAccount = updatedAccount.copyWith(
                        isRecurring: false,
                        recurringDayOfMonth: null,
                      );
                    } else {
                      print(
                        "Não foi possível calcular a próxima data para a conta recorrente paga: ${account.name}",
                      );
                    }
                  }

                  try {
                    // Atualizar apenas os campos relevantes da conta original
                    await FirebaseFirestore.instance
                        .collection('accounts')
                        .doc(account.id)
                        .update({
                          'isPaid': updatedAccount.isPaid,
                          'isRecurring':
                              updatedAccount
                                  .isRecurring, // Pode ter sido alterado se a recorrente foi paga
                          'recurringDayOfMonth':
                              updatedAccount
                                  .recurringDayOfMonth, // Pode ter sido alterado
                          'lastPaidDate':
                              updatedAccount.isPaid
                                  ? Timestamp.fromDate(account.dueDate)
                                  : (updatedAccount.lastPaidDate != null
                                      ? Timestamp.fromDate(
                                        updatedAccount.lastPaidDate!,
                                      )
                                      : null),
                        });

                    print(
                      "Status de pagamento da conta ${account.id} atualizado para ${updatedAccount.isPaid}",
                    );
                    // Chamar com o objeto 'updatedAccount' que reflete o novo status de isPaid
                    await _scheduleDailyRemindersUntilDueDate(updatedAccount);
                  } catch (e) {
                    print("Erro ao atualizar status de pagamento: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao atualizar pagamento: $e'),
                      ),
                    );
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

                  // <<< CHAMAR A NOVA FUNÇÃO DE AGENDAMENTO/CANCELAMENTO >>>
                  // Para cancelar, passamos a conta como se estivesse paga.
                  await _scheduleDailyRemindersUntilDueDate(
                    account.copyWith(isPaid: true),
                  );

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

          return ListView.builder(
            itemCount: accountsFromFirestore.length,
            itemBuilder: (context, index) {
              try {
                final DocumentSnapshot<Map<String, dynamic>> document =
                    accountsFromFirestore[index];
                final Account account = Account.fromFirestore(document);

                String subtitleText =
                    'Vencimento: ${DateFormat('dd/MM/yyyy').format(account.dueDate.toLocal())}';
                if (account.value != null) {
                  subtitleText +=
                      ' - R\$ ${account.value!.toStringAsFixed(2).replaceAll('.', ',')}';
                }

                Color itemColor = Colors.transparent;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final dueDateDayOnly = DateTime(
                  account.dueDate.year,
                  account.dueDate.month,
                  account.dueDate.day,
                );

                if (!account.isPaid) {
                  if (dueDateDayOnly.isAtSameMomentAs(today)) {
                    itemColor = Colors.red.withOpacity(0.3);
                  } else if (dueDateDayOnly.isBefore(today)) {
                    itemColor = Colors.grey.withOpacity(0.3);
                  }
                }

                String statusText = "";
                if (account.isPaid && !account.isRecurring) {
                  statusText = ' (PAGO)';
                } else if (account.isRecurring &&
                    account.lastPaidDate != null) {
                  statusText =
                      ' (Últ. Pgto: ${DateFormat('dd/MM/yyyy').format(account.lastPaidDate!)})';
                } else if (account.isRecurring) {
                  statusText =
                      " (Mensal - Dia ${account.recurringDayOfMonth ?? 'N/A'})";
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
                      (account.isPaid && !account.isRecurring)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color:
                          (account.isPaid && !account.isRecurring)
                              ? Colors.green
                              : Colors.blueGrey,
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
