import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/category.dart';
import '../models/account.dart'; // Certifique-se que este modelo usa 'lastPaidDate'
import 'package:intl/intl.dart';
import '../services/notification_service.dart'; // Para NotificationService e generateUniqueNotificationId
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class CategoryAccountsPage extends StatefulWidget {
  final Category category;

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

  // Função APENAS para notificações LOCAIS
  Future<void> _scheduleOrCancelLocalNotifications(
    Account account,
    String firestoreAccountId,
  ) async {
    // Cancela notificações antigas
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

    print(
      "LocalNotif (scheduleFunc): Checando agendamento para ${account.name}, dueDate: ${account.dueDate}, isRecurring: ${account.isRecurring}, isPaid: ${account.isPaid}",
    );

    // Agenda apenas se não for recorrente, não paga, e com data futura.
    if (!account.isRecurring &&
        !account.isPaid &&
        account.dueDate.isAfter(DateTime.now())) {
      DateTime oneDayBefore = account.dueDate.subtract(const Duration(days: 1));
      DateTime scheduledTimeOneDayBefore = DateTime(
        oneDayBefore.year,
        oneDayBefore.month,
        oneDayBefore.day,
        9,
        0,
      );

      if (scheduledTimeOneDayBefore.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: generateUniqueNotificationId(
            firestoreAccountId,
            reminderTypeSuffix: "_1day_before",
          ),
          title: 'Lembrete: Conta Vencendo Amanhã!',
          body:
              'Sua conta "${account.name}" vence amanhã, ${DateFormat('dd/MM/yyyy').format(account.dueDate.toLocal())}!',
          scheduledDateTime: scheduledTimeOneDayBefore,
          payload: firestoreAccountId,
        );
      }

      DateTime scheduledTimeDueDate = DateTime(
        account.dueDate.year,
        account.dueDate.month,
        account.dueDate.day,
        9,
        0,
      );

      if (scheduledTimeDueDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: generateUniqueNotificationId(
            firestoreAccountId,
            reminderTypeSuffix: "_due_date",
          ),
          title: 'CONTA VENCE HOJE!',
          body:
              'Sua conta "${account.name}" vence hoje (${DateFormat('dd/MM/yyyy').format(account.dueDate.toLocal())}). Não se esqueça!',
          scheduledDateTime: scheduledTimeDueDate,
          payload: firestoreAccountId,
        );
      }
    } else if (account.isRecurring) {
      print(
        "Conta recorrente '${account.name}' salva/editada. Notificações locais do molde foram canceladas. HomePage irá reagendar a próxima ocorrência.",
      );
    } else {
      // Log mais detalhado
      String reason = "";
      if (account.isRecurring) reason += "É recorrente. ";
      if (account.isPaid) reason += "Já está paga. ";
      if (!account.dueDate.isAfter(DateTime.now()))
        reason += "Data de vencimento não é futura (${account.dueDate}). ";
      print("Notificação local NÃO agendada para '${account.name}': $reason");
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
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('O nome da conta não pode estar vazio.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  return;
                }
                int? recurringDay;
                if (_isRecurringDialog) {
                  if (_recurringDayController.text.trim().isEmpty) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Informe o dia do vencimento mensal.'),
                          backgroundColor: Colors.orange,
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
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dia do vencimento mensal inválido (1-31).',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    return;
                  }
                }
                DateTime effectiveDueDateForSave = _dialogSelectedDueDate;
                if (_isRecurringDialog && recurringDay != null) {
                  try {
                    effectiveDueDateForSave = DateTime(
                      _dialogSelectedDueDate.year,
                      _dialogSelectedDueDate.month,
                      recurringDay,
                    );
                    DateTime todayForCompare = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    );
                    if (effectiveDueDateForSave.isBefore(todayForCompare) ||
                        (effectiveDueDateForSave.isAtSameMomentAs(
                              todayForCompare,
                            ) &&
                            _dialogSelectedDueDate.day > recurringDay)) {
                      effectiveDueDateForSave = DateTime(
                        _dialogSelectedDueDate.year,
                        _dialogSelectedDueDate.month + 1,
                        recurringDay,
                      );
                    }
                    if (effectiveDueDateForSave.day != recurringDay) {
                      effectiveDueDateForSave = DateTime(
                        effectiveDueDateForSave.year,
                        effectiveDueDateForSave.month + 1,
                        0,
                      );
                    }
                  } catch (e) {
                    effectiveDueDateForSave = DateTime(
                      _dialogSelectedDueDate.year,
                      _dialogSelectedDueDate.month + 1,
                      0,
                    );
                  }
                }
                final accountToSave = Account(
                  id: uuid.v4(),
                  categoryId: widget.category.id,
                  name: _accountNameController.text.trim(),
                  dueDate: effectiveDueDateForSave,
                  value:
                      _accountValueController.text.trim().isEmpty
                          ? null
                          : double.tryParse(
                            _accountValueController.text.trim(),
                          ),
                  isPaid: false,
                  isRecurring: _isRecurringDialog,
                  recurringDayOfMonth: recurringDay,
                  lastPaidDate: null,
                );
                try {
                  DocumentReference docRef = await FirebaseFirestore.instance
                      .collection('accounts')
                      .add(accountToSave.toFirestore());
                  String firestoreAccountId = docRef.id;
                  if (mounted) Navigator.of(dialogPopupContext).pop();
                  await _scheduleOrCancelLocalNotifications(
                    accountToSave.copyWith(id: firestoreAccountId),
                    firestoreAccountId,
                  );
                } catch (e) {
                  print('Erro ao adicionar conta: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao adicionar conta: $e'),
                        backgroundColor: Colors.red,
                      ),
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

  void _showEditAccountDialog(Account accountToEdit) {
    _accountNameController.text = accountToEdit.name;
    _accountValueController.text = accountToEdit.value?.toString() ?? '';
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
                        labelText: 'Valor (Opcional)',
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
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('O nome da conta não pode estar vazio.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  return;
                }
                int? recurringDay;
                DateTime effectiveDueDate = _dialogSelectedDueDate;
                if (_isRecurringDialog) {
                  if (_recurringDayController.text.trim().isEmpty) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Informe o dia do vencimento mensal.'),
                          backgroundColor: Colors.orange,
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
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dia do vencimento mensal inválido (1-31).',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    return;
                  }
                  try {
                    effectiveDueDate = DateTime(
                      _dialogSelectedDueDate.year,
                      _dialogSelectedDueDate.month,
                      recurringDay,
                    );
                  } catch (e) {
                    effectiveDueDate = DateTime(
                      _dialogSelectedDueDate.year,
                      _dialogSelectedDueDate.month + 1,
                      0,
                    );
                  }
                }

                Map<String, dynamic> dataToUpdate = {
                  'name': _accountNameController.text.trim(),
                  'dueDate': Timestamp.fromDate(effectiveDueDate),
                  'value':
                      _accountValueController.text.trim().isEmpty
                          ? null
                          : double.tryParse(
                            _accountValueController.text.trim(),
                          ),
                  'isRecurring': _isRecurringDialog,
                  'recurringDayOfMonth':
                      _isRecurringDialog ? recurringDay : null,
                  // Mantém o lastPaidDate original, a menos que a conta deixe de ser recorrente
                  'lastPaidDate':
                      !_isRecurringDialog
                          ? null
                          : (accountToEdit.lastPaidDate != null
                              ? Timestamp.fromDate(accountToEdit.lastPaidDate!)
                              : null),
                  // isPaid não é editado aqui diretamente, mas é mantido do objeto original para consistência
                  'isPaid': accountToEdit.isPaid,
                };

                try {
                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountToEdit.id)
                      .update(dataToUpdate);

                  Account contaAtualizada = Account(
                    id: accountToEdit.id,
                    categoryId: accountToEdit.categoryId,
                    name: dataToUpdate['name'],
                    dueDate: effectiveDueDate,
                    value: dataToUpdate['value'] as double?,
                    isPaid:
                        accountToEdit
                            .isPaid, // Usa o isPaid original para a lógica de notificação
                    isRecurring: dataToUpdate['isRecurring'],
                    recurringDayOfMonth: dataToUpdate['recurringDayOfMonth'],
                    lastPaidDate: accountToEdit.lastPaidDate,
                  );

                  if (mounted) Navigator.of(dialogPopupContext).pop();
                  await _scheduleOrCancelLocalNotifications(
                    contaAtualizada,
                    contaAtualizada.id,
                  );
                } catch (e) {
                  print('Erro ao atualizar conta: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao atualizar conta: $e'),
                        backgroundColor: Colors.red,
                      ),
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
                  // Apenas cancela notificações locais
                  await NotificationService().cancelNotification(
                    generateUniqueNotificationId(
                      accountId,
                      reminderTypeSuffix: "_1day_before",
                    ),
                  );
                  await NotificationService().cancelNotification(
                    generateUniqueNotificationId(
                      accountId,
                      reminderTypeSuffix: "_due_date",
                    ),
                  );

                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountId)
                      .delete();
                  if (mounted) Navigator.of(dialogPopupContext).pop();
                } catch (e) {
                  print('Erro ao excluir conta: $e');
                  if (mounted) {
                    Navigator.of(dialogPopupContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao excluir conta: $e'),
                        backgroundColor: Colors.red,
                      ),
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('accounts')
                .where('categoryId', isEqualTo: widget.category.id)
                .orderBy('dueDate')
                .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final accountsFromFirestore = snapshot.data?.docs;
          if (accountsFromFirestore == null || accountsFromFirestore.isEmpty) {
            return const Center(child: Text('Não há contas nesta categoria.'));
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
                  subtitleText += ' - R\$ ${account.value!.toStringAsFixed(2)}';
                }
                if (account.isPaid && !account.isRecurring) {
                  subtitleText += ' (PAGO)';
                }
                if (account.isRecurring && account.lastPaidDate != null) {
                  subtitleText +=
                      ' (Últ. Pgto: ${DateFormat('dd/MM/yyyy').format(account.lastPaidDate!)})';
                }
                return ListTile(
                  title: Text(
                    account.name +
                        (account.isRecurring
                            ? " (Mensal - Dia ${account.recurringDayOfMonth ?? 'N/A'})"
                            : ""),
                  ),
                  subtitle: Text(subtitleText),
                  leading: Icon(
                    (account.isPaid && !account.isRecurring)
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color:
                        (account.isPaid && !account.isRecurring)
                            ? Colors.green
                            : Colors.grey,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showAccountOptions(account),
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
