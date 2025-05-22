import 'dart:io'; // Para Platform.isAndroid
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// <<< AJUSTE NO IMPORT DE CATEGORY para evitar conflito >>>
import '../models/category.dart' as app_category;
import '../models/account.dart';
import '../services/notification_service.dart';
import '../services/alarm_callback_service.dart';

var uuid = Uuid();

class CategoryAccountsPage extends StatefulWidget {
  // <<< USA A SUA CATEGORY COM PREFIXO >>>
  final app_category.Category category;

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

  Future<void> _scheduleOrCancelAlarmsAndNotifications(
    Account account,
    String firestoreAccountId,
  ) async {
    // IDs para Notificações Locais
    int localNotifId1DayBefore = generateUniqueNotificationId(
      firestoreAccountId,
      reminderTypeSuffix: "_1day_before_local",
    );
    int localNotifIdDueDate = generateUniqueNotificationId(
      firestoreAccountId,
      reminderTypeSuffix: "_due_date_local_via_alarm_test",
    ); // Usando o ID que o alarme usaria

    // IDs para Alarmes do Android
    int alarmId1DayBefore = generateUniqueNotificationId(
      firestoreAccountId,
      reminderTypeSuffix: "_alarm_1day",
    );
    int alarmIdDueDate = generateUniqueNotificationId(
      firestoreAccountId,
      reminderTypeSuffix: "_alarm_actual_test",
    ); // Renomeado para o teste do alarme

    // 1. Cancelar tudo o que pode existir para esta conta
    await NotificationService().cancelNotification(localNotifId1DayBefore);
    await NotificationService().cancelNotification(localNotifIdDueDate);
    if (!kIsWeb && Platform.isAndroid) {
      print(
        "Tentando cancelar alarmes para $firestoreAccountId: ID1=$alarmId1DayBefore, ID2=$alarmIdDueDate",
      );
      await AndroidAlarmManager.cancel(alarmId1DayBefore);
      await AndroidAlarmManager.cancel(alarmIdDueDate);
    }

    print(
      "ALARM/NOTIF DEBUG (scheduleFunc): Checando agendamento para ${account.name}, dueDate: ${account.dueDate}, isRecurring: ${account.isRecurring}, isPaid: ${account.isPaid}",
    );

    if (!account.isRecurring &&
        !account.isPaid &&
        account.dueDate.isAfter(DateTime.now())) {
      DateTime alarmOrNotificationTime = account.dueDate;

      if (!kIsWeb && Platform.isAndroid) {
        if (alarmOrNotificationTime.isAfter(
          DateTime.now().add(const Duration(seconds: 2)),
        )) {
          print(
            "Agendando ALARME (TESTE) para ${account.name} em $alarmOrNotificationTime com ID de alarme $alarmIdDueDate",
          ); // Usando alarmIdDueDate
          bool scheduled = await AndroidAlarmManager.oneShotAt(
            alarmOrNotificationTime,
            alarmIdDueDate, // ID ÚNICO DO ALARME
            alarmCallback,
            exact: true,
            wakeup: true,
            params: {
              "accountId": firestoreAccountId, "accountName": account.name,
              "title": "ALARME DISPAROU!",
              "body":
                  "Conta (TESTE ALARME) \"${account.name}\" venceu às ${DateFormat('HH:mm').format(alarmOrNotificationTime.toLocal())}!",
              "notificationId":
                  localNotifIdDueDate, // ID para a notificação local que o callback vai disparar
            },
          );
          if (scheduled) {
            print(
              ">>> SUCESSO: Alarme de teste agendado para $alarmOrNotificationTime",
            );
          } else {
            print(
              ">>> FALHA: Alarme de teste NÃO agendado para $alarmOrNotificationTime",
            );
          }
        } else {
          print(
            "ALARM TEST: Horário do alarme ($alarmOrNotificationTime) já passou ou muito próximo de ${DateTime.now()}. Não agendando alarme.",
          );
        }
      } else {
        print(
          "ALARM TEST: Plataforma é Web ou não Android. Usando Notificação Local para teste de horário.",
        );
        if (alarmOrNotificationTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: localNotifIdDueDate, // Usando o ID da notificação local
            title: 'TESTE NOTIFICAÇÃO (${kIsWeb ? "Web" : "iOS"})!',
            body:
                'Conta "${account.name}" vence ${DateFormat('HH:mm').format(alarmOrNotificationTime.toLocal())} (Teste)',
            scheduledDateTime: alarmOrNotificationTime,
            payload: firestoreAccountId,
          );
        }
      }
    } else if (account.isRecurring) {
      print("Conta recorrente '${account.name}'. HomePage irá reagendar.");
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
                  /* ... */
                  return;
                }
                int? recurringDay;
                if (_isRecurringDialog) {
                  /* ... */
                }
                DateTime effectiveDueDateForSave = _dialogSelectedDueDate;
                if (_isRecurringDialog && recurringDay != null) {
                  /* ... lógica de cálculo de effectiveDueDateForSave ... */
                }

                // <<< BLOCO DE TESTE PARA AGENDAR PARA DAQUI A 10 MINUTOS >>>
                DateTime dateForScheduling;
                bool isTestScheduling = false;
                if (!_isRecurringDialog) {
                  isTestScheduling = true;
                  dateForScheduling = DateTime.now().add(
                    const Duration(minutes: 10),
                  );
                  print(
                    "ALARM TEST (AddDialog): Data REAL de vencimento para salvar: $effectiveDueDateForSave.",
                  );
                  print(
                    "ALARM TEST (AddDialog): ALARME/NOTIFICAÇÃO será agendada para $dateForScheduling (daqui a 10 min)",
                  );
                } else {
                  dateForScheduling = effectiveDueDateForSave;
                }
                // <<< FIM DO BLOCO DE TESTE >>>

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

                  Account accountForScheduling = accountToSave.copyWith(
                    id: firestoreAccountId,
                    dueDate: dateForScheduling,
                  );
                  await _scheduleOrCancelAlarmsAndNotifications(
                    accountForScheduling,
                    firestoreAccountId,
                  );
                } catch (e) {
                  /* ... */
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
                  /* ... */
                  return;
                }
                int? recurringDay;
                DateTime effectiveDueDate = _dialogSelectedDueDate;
                if (_isRecurringDialog) {
                  /* ... */
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
                  'lastPaidDate':
                      !_isRecurringDialog
                          ? null
                          : (accountToEdit.lastPaidDate != null
                              ? Timestamp.fromDate(accountToEdit.lastPaidDate!)
                              : null),
                  'isPaid': accountToEdit.isPaid,
                };
                try {
                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountToEdit.id)
                      .update(dataToUpdate);
                  Account contaAtualizada = accountToEdit.copyWith(
                    name: dataToUpdate['name'],
                    dueDate: effectiveDueDate,
                    value: dataToUpdate['value'] as double?,
                    isRecurring: dataToUpdate['isRecurring'],
                    recurringDayOfMonth: dataToUpdate['recurringDayOfMonth'],
                    lastPaidDate:
                        (dataToUpdate['lastPaidDate'] as Timestamp?)?.toDate(),
                    isPaid: accountToEdit.isPaid,
                  );
                  if (mounted) Navigator.of(dialogPopupContext).pop();
                  await _scheduleOrCancelAlarmsAndNotifications(
                    contaAtualizada,
                    contaAtualizada.id,
                  );
                } catch (e) {
                  /* ... */
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
                  await NotificationService().cancelNotification(
                    generateUniqueNotificationId(
                      accountId,
                      reminderTypeSuffix: "_1day_before_local",
                    ),
                  );
                  await NotificationService().cancelNotification(
                    generateUniqueNotificationId(
                      accountId,
                      reminderTypeSuffix: "_due_date_local_via_alarm",
                    ),
                  );
                  if (!kIsWeb && Platform.isAndroid) {
                    await AndroidAlarmManager.cancel(
                      generateUniqueNotificationId(
                        accountId,
                        reminderTypeSuffix: "_alarm_1day",
                      ),
                    );
                    await AndroidAlarmManager.cancel(
                      generateUniqueNotificationId(
                        accountId,
                        reminderTypeSuffix: "_alarm_actual_test",
                      ),
                    ); // Mudado para o ID do alarme de teste
                  }
                  await FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(accountId)
                      .delete();
                  if (mounted) Navigator.of(dialogPopupContext).pop();
                } catch (e) {
                  /* ... */
                }
              },
            ),
          ],
        );
      },
    );
  }

  // <<< MÉTODO BUILD COMPLETO >>>
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

extension TimeOfDayExtension on TimeOfDay {
  DateTime toDateTime(DateTime date) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
