import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/category.dart';
import '../models/account.dart';
import '../services/notification_service.dart';
import 'category_accounts_page.dart';
import 'reports_page.dart';
import 'edit_profile_page.dart'; // Importa a tela de edição de perfil

var uuid = Uuid();

// Seu MolduraPainter (mantido como estava)
class MolduraPainter extends CustomPainter {
  final Color startColor;
  final Color endColor;
  final double waveHeight;

  MolduraPainter({
    required this.startColor,
    required this.endColor,
    this.waveHeight = 120,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final pathTop = Path();
    pathTop.moveTo(0, 0);
    pathTop.lineTo(0, waveHeight);
    pathTop.quadraticBezierTo(
      size.width / 2,
      waveHeight + 30,
      size.width,
      waveHeight,
    );
    pathTop.lineTo(size.width, 0);
    pathTop.close();
    final pathBottom = Path();
    pathBottom.moveTo(0, size.height);
    pathBottom.lineTo(0, size.height - waveHeight);
    pathBottom.quadraticBezierTo(
      size.width / 2,
      size.height - waveHeight - 30,
      size.width,
      size.height - waveHeight,
    );
    pathBottom.lineTo(size.width, size.height);
    pathBottom.close();
    canvas.drawPath(pathTop, paint);
    canvas.drawPath(pathBottom, paint);
  }

  @override
  bool shouldRepaint(covariant MolduraPainter oldDelegate) {
    return oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.waveHeight != waveHeight;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final List<Category> _categories = [];
  final List<Account> _paidAccounts = [];
  final TextEditingController _categoryNameController = TextEditingController();

  late AnimationController _blinkController;
  late Animation<Color?> _blinkColorAnimation;

  final Set<Account> _selectedAccounts = {};
  bool _selectionMode = false;

  final Stream<QuerySnapshot> _categoriesStream =
      FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _upcomingAccountsStream;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _blinkColorAnimation = ColorTween(
      begin: Colors.blue.shade100,
      end: Colors.blue.shade300,
    ).animate(_blinkController);

    _blinkController.addListener(() {
      if (mounted && _selectionMode && _blinkController.isAnimating) {
        setState(() {});
      }
    });
    _initializeUpcomingAccountsStream();
    _loadInitialPaidAccounts(); // Chamar aqui para carregar as contas pagas ao iniciar a Home
  }

  void _manageBlinkControllerForSelection() {
    if (!mounted) return;
    if (_selectionMode && _selectedAccounts.isNotEmpty) {
      if (!_blinkController.isAnimating) {
        _blinkController.repeat(reverse: true);
      }
    } else {
      if (_blinkController.isAnimating) {
        _blinkController.stop();
      }
    }
  }

  void _initializeUpcomingAccountsStream() {
    _upcomingAccountsStream = FirebaseFirestore.instance
        .collection('accounts')
        .orderBy('dueDate', descending: false)
        .snapshots()
        .handleError((error) {
          print("Erro ao carregar contas próximas: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao carregar contas: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return Stream.empty();
        });
  }

  Widget _buildIconOption(
    IconData iconData,
    IconData? selectedIcon,
    VoidCallback onTapCallback,
  ) {
    final isSelected = selectedIcon == iconData;
    return GestureDetector(
      onTap: onTapCallback,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: Icon(iconData, color: Colors.blue, size: 30.0),
      ),
    );
  }

  IconData? _getCategoryIconForAccount(String categoryId) {
    if (categoryId.isEmpty) return Icons.label_outline;
    try {
      final category = _categories.firstWhere((cat) => cat.id == categoryId);
      return category.icon ?? Icons.label_outline;
    } catch (e) {
      return Icons.label_important_outline;
    }
  }

  String _getCategoryNameForAccount(String categoryId) {
    if (categoryId.isEmpty) return 'Sem Categoria';
    try {
      final category = _categories.firstWhere((cat) => cat.id == categoryId);
      return category.name.isNotEmpty ? category.name : 'Categoria S/ Nome';
    } catch (e) {
      return 'Desconhecida';
    }
  }

  void _showCategoryOptions(Category category) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Renomear Categoria'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameCategoryDialog(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Excluir Categoria'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteCategoryDialog(category);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    _categoryNameController.clear();
    IconData? _dialogSelectedIcon;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nova Categoria'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _categoryNameController,
                      decoration: const InputDecoration(
                        hintText: 'Nome da Categoria',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escolha um Ícone:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildIconOption(
                          Icons.folder,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.folder,
                          ),
                        ),
                        _buildIconOption(
                          Icons.shopping_bag,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.shopping_bag,
                          ),
                        ),
                        _buildIconOption(
                          Icons.home,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.home,
                          ),
                        ),
                        _buildIconOption(
                          Icons.directions_car,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.directions_car,
                          ),
                        ),
                        _buildIconOption(
                          Icons.school,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.school,
                          ),
                        ),
                        _buildIconOption(
                          Icons.fastfood,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.fastfood,
                          ),
                        ),
                        _buildIconOption(
                          Icons.health_and_safety,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.health_and_safety,
                          ),
                        ),
                        _buildIconOption(
                          Icons.work,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.work,
                          ),
                        ),
                        _buildIconOption(
                          Icons.attach_money,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.attach_money,
                          ),
                        ),
                        _buildIconOption(
                          Icons.fitness_center,
                          _dialogSelectedIcon,
                          () => setStateDialog(
                            () => _dialogSelectedIcon = Icons.fitness_center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
                _categoryNameController.clear();
              },
            ),
            TextButton(
              child: const Text('Adicionar'),
              onPressed: () async {
                final newCategoryName = _categoryNameController.text.trim();
                if (newCategoryName.isEmpty) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'O nome da categoria não pode estar vazio.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  return;
                }
                if (_dialogSelectedIcon == null) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, selecione um ícone para a categoria.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  return;
                }
                try {
                  final querySnapshot =
                      await FirebaseFirestore.instance
                          .collection('categories')
                          .where('name', isEqualTo: newCategoryName)
                          .limit(1)
                          .get();
                  if (querySnapshot.docs.isNotEmpty) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Uma categoria com este nome já existe.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                  await FirebaseFirestore.instance
                      .collection('categories')
                      .add({
                        'name': newCategoryName,
                        'iconCodePoint': _dialogSelectedIcon?.codePoint,
                        'iconFontFamily': _dialogSelectedIcon?.fontFamily,
                        'iconFontPackage': _dialogSelectedIcon?.fontPackage,
                      });
                  if (mounted) Navigator.of(context).pop();
                  _categoryNameController.clear();
                } catch (e) {
                  print('Erro ao adicionar categoria: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao adicionar categoria: $e'),
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

  void _showRenameCategoryDialog(Category category) {
    _categoryNameController.text = category.name;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Renomear Categoria'),
          content: TextField(
            controller: _categoryNameController,
            decoration: const InputDecoration(
              hintText: 'Novo nome da Categoria',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () async {
                final newCategoryName = _categoryNameController.text.trim();
                if (newCategoryName.isNotEmpty &&
                    newCategoryName != category.name) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('categories')
                        .doc(category.id)
                        .update({'name': newCategoryName});
                    if (mounted) Navigator.of(context).pop();
                    _categoryNameController.clear();
                  } catch (e) {
                    print('Erro ao renomear categoria: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao renomear categoria: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (newCategoryName.isEmpty) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'O nome da categoria não pode estar vazio.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                } else {
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Excluir Categoria'),
          content: Text(
            'Tem certeza que deseja excluir a categoria "${category.name}"? Todas as contas associadas a esta categoria também serão permanentemente excluídas.', // Texto de aviso alterado
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ), // Destaca o botão de excluir
              onPressed: () async {
                try {
                  // 1. Busca todas as contas que pertencem a esta categoria
                  QuerySnapshot accountsSnapshot =
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .where('categoryId', isEqualTo: category.id)
                          .get();

                  WriteBatch batch = FirebaseFirestore.instance.batch();

                  // 2. Adiciona cada conta encontrada ao batch para exclusão
                  for (DocumentSnapshot doc in accountsSnapshot.docs) {
                    batch.delete(
                      doc.reference,
                    ); // MUDANÇA AQUI: Deleta o documento da conta
                  }

                  // 3. Executa o batch de exclusão das contas
                  await batch.commit();

                  // 4. Exclui a categoria em si
                  await FirebaseFirestore.instance
                      .collection('categories')
                      .doc(category.id)
                      .delete();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      // Use ScaffoldMessenger
                      SnackBar(
                        content: Text(
                          'Categoria "${category.name}" e todas as contas associadas foram excluídas.', // Mensagem de sucesso alterada
                        ),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  print('Erro ao excluir categoria e contas: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      // Use ScaffoldMessenger
                      SnackBar(
                        content: Text('Erro ao excluir categoria e contas: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadInitialPaidAccounts() async {
    print("--- Iniciando _loadInitialPaidAccounts ---");
    try {
      // Ajuste na consulta: remova a condição isRecurring: false
      QuerySnapshot paidSnapshot =
          await FirebaseFirestore.instance
              .collection('accounts')
              .where(
                'isPaid',
                isEqualTo: true,
              ) // Busca todas as contas marcadas como pagas
              .get();

      print(
        "Consulta ao Firestore para contas pagas retornou ${paidSnapshot.docs.length} documentos.",
      );

      final List<Account> loadedPaidAccounts =
          paidSnapshot.docs.map((doc) {
            print(
              "  Processando documento pago: ${doc.id}, Dados: ${doc.data()}",
            );
            return Account.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            );
          }).toList();

      if (mounted) {
        setState(() {
          _paidAccounts.clear();
          _paidAccounts.addAll(loadedPaidAccounts);
          print(
            "Contas pagas iniciais carregadas e _paidAccounts atualizada. Total: ${_paidAccounts.length}",
          );
          _paidAccounts.forEach(
            (acc) => print(
              "  >> Na lista _paidAccounts: ${acc.name}, Valor: ${acc.value}, Paga: ${acc.isPaid}, Rec: ${acc.isRecurring}, PaidDate: ${acc.paidDate}",
            ), // Adicionei PaidDate no print para depuração
          );
        });
      }
    } catch (e, s) {
      print("Erro CRÍTICO ao carregar contas pagas iniciais: $e");
      print("StackTrace: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar histórico de contas pagas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleNotificationsForUpcomingRecurring(Account molde) async {
    if (!molde.isRecurring || molde.id.isEmpty) return;

    await NotificationService().cancelNotification(
      generateUniqueNotificationId(
        molde.id,
        reminderTypeSuffix: "_1day_before",
      ),
    );
    await NotificationService().cancelNotification(
      generateUniqueNotificationId(
        molde.id,
        reminderTypeSuffix: "_due_date",
      ), // CORRIGIDO AQUI
    );

    DateTime? proximoVencimento = molde.nextPotentialDueDateForRecurringMolde;
    print(
      "HomePage - Agendando para próxima recorrente: ${molde.name}, Próximo Venc: $proximoVencimento",
    );

    if (proximoVencimento != null &&
        proximoVencimento.isAfter(DateTime.now())) {
      DateTime umDiaAntes = proximoVencimento.subtract(const Duration(days: 1));
      DateTime horaAgendamentoUmDiaAntes = DateTime(
        umDiaAntes.year,
        umDiaAntes.month,
        umDiaAntes.day,
        9,
        0,
      );
      if (horaAgendamentoUmDiaAntes.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: generateUniqueNotificationId(
            molde.id,
            reminderTypeSuffix: "_1day_before",
          ),
          title: 'Lembrete Recorrente: Vence Amanhã!',
          body:
              'Sua conta mensal "${molde.name}" vence amanhã, ${DateFormat('dd/MM/yyyy').format(proximoVencimento.toLocal())}!',
          scheduledDateTime: horaAgendamentoUmDiaAntes,
          payload: molde.id,
        );
      }
      DateTime horaAgendamentoDia = DateTime(
        proximoVencimento.year,
        proximoVencimento.month,
        proximoVencimento.day,
        9,
        0,
      );
      if (horaAgendamentoDia.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: generateUniqueNotificationId(
            molde.id,
            reminderTypeSuffix: "_due_date",
          ),
          title: 'CONTA MENSAL VENCE HOJE!',
          body:
              'Sua conta mensal "${molde.name}" vence hoje, ${DateFormat('dd/MM/yyyy').format(proximoVencimento.toLocal())}!',
          scheduledDateTime: horaAgendamentoDia,
          payload: molde.id,
        );
      }
    } else {
      print(
        "HomePage - Próximo vencimento para ${molde.name} é nulo ou no passado, não reagendando notificação.",
      );
    }
  }

  void _markSelectedAccountsAsPaid() async {
    if (_selectedAccounts.isEmpty) return;
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    final Set<Account> accountsSuccessfullyProcessed = {};

    for (var accountOriginal in _selectedAccounts) {
      if (accountOriginal.isRecurring &&
          accountOriginal.recurringDayOfMonth != null) {
        DateTime? ocorrenciaAtualDueDate =
            accountOriginal.nextPotentialDueDateForRecurringMolde;

        if (ocorrenciaAtualDueDate != null) {
          Account instanciaPaga = accountOriginal.copyWith(
            createPaidInstance: true,
            occurrenceDueDate: ocorrenciaAtualDueDate,
          );
          DocumentReference novaInstanciaRef = FirebaseFirestore.instance
              .collection('accounts')
              .doc(instanciaPaga.id);
          batch.set(novaInstanciaRef, instanciaPaga.toFirestore());

          DocumentReference contaOriginalRef = FirebaseFirestore.instance
              .collection('accounts')
              .doc(accountOriginal.id);
          batch.update(contaOriginalRef, {
            'lastPaidDate': Timestamp.fromDate(ocorrenciaAtualDueDate),
          });

          accountsSuccessfullyProcessed.add(
            accountOriginal.copyWith(lastPaidDate: ocorrenciaAtualDueDate),
          );
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Não foi possível determinar o vencimento de ${accountOriginal.name}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
        }
      } else {
        // --- INÍCIO DA ALTERAÇÃO IMPORTANTE AQUI PARA paidDate ---
        DocumentReference accountRef = FirebaseFirestore.instance
            .collection('accounts')
            .doc(accountOriginal.id);
        batch.update(accountRef, {
          'isPaid': true,
          'paidDate': Timestamp.fromDate(
            DateTime.now(),
          ), // <-- ADICIONADO: Define paidDate para contas não recorrentes
        });
        // --- FIM DA ALTERAÇÃO IMPORTANTE AQUI ---

        await NotificationService().cancelNotification(
          generateUniqueNotificationId(
            accountOriginal.id,
            reminderTypeSuffix: "_1day_before",
          ),
        );
        await NotificationService().cancelNotification(
          generateUniqueNotificationId(
            accountOriginal.id,
            reminderTypeSuffix: "_due_date",
          ),
        );
        accountsSuccessfullyProcessed.add(accountOriginal);
      }
    }

    if (accountsSuccessfullyProcessed.isNotEmpty) {
      try {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${accountsSuccessfullyProcessed.length} conta(s) processada(s) como paga(s).',
              ),
            ),
          );
        }
        for (var moldeProcessado in accountsSuccessfullyProcessed) {
          if (moldeProcessado.isRecurring) {
            await _scheduleNotificationsForUpcomingRecurring(moldeProcessado);
          }
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao marcar contas como pagas: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
    _clearSelection();
  }

  Future<void> _scheduleNewDateForSelectedAccounts() async {
    if (_selectedAccounts.isEmpty) return;
    final DateTime now = DateTime.now();
    final DateTime firstSelectableDate = DateTime(now.year, now.month, now.day);

    DateTime initialPickerDate = _selectedAccounts.first.dueDate;
    if (initialPickerDate.isBefore(firstSelectableDate)) {
      initialPickerDate = firstSelectableDate;
    }

    final DateTime? newDatePicked = await showDatePicker(
      context: context,
      initialDate: initialPickerDate,
      firstDate: firstSelectableDate,
      lastDate: DateTime(now.year + 10, now.month, now.day),
    );

    if (newDatePicked != null) {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final Set<Account> accountsToProcess = Set.from(_selectedAccounts);

      for (var account in accountsToProcess) {
        DocumentReference accountRef = FirebaseFirestore.instance
            .collection('accounts')
            .doc(account.id);
        DateTime newEffectiveDueDate = DateTime(
          newDatePicked.year,
          newDatePicked.month,
          newDatePicked.day,
          account.dueDate.hour,
          account.dueDate.minute,
        );
        Map<String, dynamic> updateData = {
          'dueDate': Timestamp.fromDate(newEffectiveDueDate),
        };

        if (account.isRecurring) {
          updateData['recurringDayOfMonth'] = newEffectiveDueDate.day;
          updateData['lastPaidDate'] = null;

          await NotificationService().cancelNotification(
            generateUniqueNotificationId(
              account.id,
              reminderTypeSuffix: "_1day_before",
            ),
          );
          await NotificationService().cancelNotification(
            generateUniqueNotificationId(
              account.id,
              reminderTypeSuffix: "_due_date",
            ),
          );
        } else {
          await NotificationService().cancelNotification(
            generateUniqueNotificationId(
              account.id,
              reminderTypeSuffix: "_1day_before",
            ),
          );
          await NotificationService().cancelNotification(
            generateUniqueNotificationId(
              account.id,
              reminderTypeSuffix: "_due_date",
            ),
          );
        }
        batch.update(accountRef, updateData);
      }
      try {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Data reagendada para ${accountsToProcess.length} conta(s).',
              ),
            ),
          );
        }
        for (var account in accountsToProcess) {
          if (account.isRecurring) {
            DocumentSnapshot updatedMoldeDoc =
                await FirebaseFirestore.instance
                    .collection('accounts')
                    .doc(account.id)
                    .get();
            if (updatedMoldeDoc.exists) {
              Account moldeAtualizado = Account.fromFirestore(
                updatedMoldeDoc as DocumentSnapshot<Map<String, dynamic>>,
              );
              await _scheduleNotificationsForUpcomingRecurring(moldeAtualizado);
            }
          }
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao reagendar: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
      _clearSelection();
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print("Erro ao fazer logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sair: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleAccountSelection(Account account) {
    setState(() {
      final isCurrentlySelected = _selectedAccounts.any(
        (acc) => acc.id == account.id,
      );
      if (isCurrentlySelected) {
        _selectedAccounts.removeWhere((acc) => acc.id == account.id);
      } else {
        _selectedAccounts.add(account);
      }

      if (_selectedAccounts.isEmpty) {
        _selectionMode = false;
      } else {
        _selectionMode = true;
      }
      _manageBlinkControllerForSelection();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedAccounts.clear();
      _selectionMode = false;
      _manageBlinkControllerForSelection();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double topFrameHeight = 80;
    const double bottomFrameHeight = 80;
    const double selectionActionButtonsAreaHeight = 75;
    const double centralFloatingButtonsAreaHeight = 90;

    const double drawerCategoryListItemHeightEstimate = 48.0;
    const int maxVisibleCategoriesInDrawer = 5;
    final double categoriesDrawerMaxHeight =
        drawerCategoryListItemHeightEstimate * maxVisibleCategoriesInDrawer;

    final DateTime now = DateTime.now();
    final DateTime nowOnly = DateTime(now.year, now.month, now.day);
    final DateTime tomorrowOnly = DateTime(now.year, now.month, now.day + 1);
    final DateTime tenDaysFromTodayEnd = DateTime(
      now.year,
      now.month,
      now.day + 10,
      23,
      59,
      59,
    );

    // StreamBuilder para observar o estado do usuário (para o DrawerHeader)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnapshot) {
        User? currentUser = userSnapshot.data; // Pega o usuário mais atualizado

        // FutureBuilder para carregar o ícone de avatar customizado (se não houver photoURL)
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              currentUser != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .get()
                  : Future.value(
                    null,
                  ), // Se não há usuário, não busca no Firestore
          builder: (context, userDocSnapshot) {
            IconData? customAvatarIcon;
            if (userDocSnapshot.hasData &&
                userDocSnapshot.data != null &&
                userDocSnapshot.data!.exists) {
              Map<String, dynamic> userData = userDocSnapshot.data!.data()!;
              int? codePoint = userData['avatarIconCodePoint'];
              String? fontFamily = userData['avatarIconFontFamily'];
              String? fontPackage =
                  userData['avatarIconFontPackage']; // Corrigido: fontPackage para avatarIconFontPackage

              if (codePoint != null && fontFamily != null) {
                customAvatarIcon = IconData(
                  codePoint,
                  fontFamily: fontFamily,
                  fontPackage: fontPackage,
                );
              }
            }

            return Scaffold(
              appBar: AppBar(
                title:
                    _selectionMode
                        ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSelection,
                            ),
                            Expanded(
                              child: Text(
                                '${_selectedAccounts.length} selecionado${_selectedAccounts.length > 1 ? 's' : ''}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.credit_card),
                            SizedBox(width: 8),
                            Text(
                              'LEMBREI DE PAGAR',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                centerTitle: true,
              ),
              drawer: Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // DrawerHeader AGORA EXIBINDO INFORMAÇÕES DO USUÁRIO E BOTÃO DE EDIÇÃO
                    DrawerHeader(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade400, // Fundo azul suave
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start, // Alinhado à esquerda para as informações do usuário
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Stack(
                            // O Stack precisa envolver os elementos que se sobrepõem
                            alignment:
                                Alignment
                                    .bottomRight, // Alinha os filhos não posicionados ao canto inferior direito
                            children: [
                              // Avatar (com imagem ou ícone)
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    currentUser?.photoURL != null
                                        ? NetworkImage(currentUser!.photoURL!)
                                        : null,
                                child:
                                    currentUser?.photoURL == null
                                        ? Icon(
                                          customAvatarIcon ??
                                              Icons
                                                  .person, // Usa o ícone customizado ou Icons.person como padrão
                                          size: 28,
                                          color: Colors.blue.shade400,
                                        )
                                        : null,
                              ),
                              // Botão de edição (canetinha) posicionado sobre o avatar
                              Positioned(
                                bottom:
                                    -4, // Ajuste este valor para mover para cima ou para baixo
                                right:
                                    -4, // Ajuste este valor para mover para a esquerda ou para a direita
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context); // Fecha o drawer
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const EditProfilePage(),
                                      ),
                                    ).then(
                                      (_) => setState(() {}),
                                    ); // Atualiza a Home após voltar
                                  },
                                  borderRadius: BorderRadius.circular(
                                    15,
                                  ), // Para o InkWell
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors
                                              .blue
                                              .shade700, // Cor de fundo da canetinha
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ), // Canetinha branca menor
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 8,
                          ), // Espaço entre o avatar e o nome/email
                          Text(
                            currentUser?.displayName ?? 'Usuário sem nome',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentUser?.email ?? 'email@exemplo.com',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Fim do DrawerHeader ajustado
                    ListTile(
                      leading: Icon(Icons.home, color: Colors.blue[600]),
                      title: Text(
                        'Início',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      onTap: () => Navigator.pop(context),
                    ),

                    // O ListTile 'Editar Perfil / Avatar' FOI REMOVIDO DAQUI
                    // Ele agora é acessado diretamente pelo botão de edição no DrawerHeader.
                    StreamBuilder<QuerySnapshot>(
                      stream: _categoriesStream,
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<QuerySnapshot> snapshot,
                      ) {
                        if (snapshot.hasError) {
                          return ListTile(
                            title: Text(
                              'Erro ao carregar categorias',
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        _categories.clear();
                        final categoriesFromFirestore = snapshot.data!.docs;
                        for (var document in categoriesFromFirestore) {
                          if (document.data() != null) {
                            Map<String, dynamic> data =
                                document.data()! as Map<String, dynamic>;
                            final categoryName = data['name'] as String?;
                            final iconCodePoint = data['iconCodePoint'] as int?;
                            final iconFontFamily =
                                data['iconFontFamily'] as String?;
                            final iconFontPackage =
                                data['iconFontPackage']
                                    as String?; // Corrigido aqui
                            IconData? categoryIcon;
                            if (iconCodePoint != null &&
                                iconFontFamily != null) {
                              try {
                                categoryIcon = IconData(
                                  iconCodePoint,
                                  fontFamily: iconFontFamily,
                                  fontPackage: iconFontPackage,
                                );
                              } catch (e) {
                                // Em caso de erro ao criar IconData, use um ícone padrão
                                categoryIcon = Icons.folder;
                              }
                            } else {
                              categoryIcon =
                                  Icons
                                      .folder; // Ícone padrão se dados estiverem faltando
                            }
                            _categories.add(
                              Category(
                                id: document.id,
                                name: categoryName ?? 'Categoria Sem Nome',
                                icon: categoryIcon,
                              ),
                            );
                          }
                        }
                        final allCategoryListTiles =
                            _categories.map((category) {
                              return ListTile(
                                leading: Icon(
                                  category.icon ?? Icons.folder,
                                  size: 24,
                                  color: Colors.blue[600],
                                ),
                                title: Text(
                                  category.name.isNotEmpty
                                      ? (category.name[0].toUpperCase() +
                                          category.name
                                              .substring(1)
                                              .toLowerCase())
                                      : 'Categoria S/ Nome',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showCategoryOptions(category);
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => CategoryAccountsPage(
                                            category: category,
                                          ),
                                    ),
                                  ).then((_) => setState(() {}));
                                },
                              );
                            }).toList();
                        return ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 0,
                          ),
                          childrenPadding: EdgeInsets.zero,
                          iconColor: Colors.blue[600],
                          collapsedIconColor: Colors.blue[600],
                          leading: Icon(
                            Icons.category,
                            color: Colors.blue[600],
                          ),
                          title: Text(
                            'Categorias',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                          initiallyExpanded: true,
                          children: [
                            if (_categories.isEmpty)
                              ListTile(
                                title: Text(
                                  'Nenhuma categoria adicionada.',
                                  style: GoogleFonts.poppins(),
                                ),
                              )
                            else
                              Container(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      _categories.length >
                                              maxVisibleCategoriesInDrawer
                                          ? categoriesDrawerMaxHeight
                                          : _categories.length *
                                              drawerCategoryListItemHeightEstimate,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: allCategoryListTiles,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.show_chart, color: Colors.blue[600]),
                      title: Text(
                        'Relatórios',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ReportsPage(
                                  paidAccounts: _paidAccounts,
                                  categories: _categories,
                                ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                      ),
                      title: Text(
                        'Sobre',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      onTap: () => Navigator.pop(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.red[400]),
                      title: Text(
                        'Sair',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[400],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _signOut();
                      },
                    ),
                  ],
                ),
              ),
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MolduraPainter(
                          startColor: Colors.blue.shade300,
                          endColor: Colors.blue.shade800,
                          waveHeight: topFrameHeight,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        SizedBox(height: topFrameHeight),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color:
                                    _selectionMode &&
                                            _selectedAccounts.isNotEmpty
                                        ? Colors.deepOrange.shade800
                                        : Colors.deepOrange,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Contas Próximas a Vencer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      _selectionMode &&
                                              _selectedAccounts.isNotEmpty
                                          ? Colors.black
                                          : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: _upcomingAccountsStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError)
                                return Center(
                                  child: Text('Erro: ${snapshot.error}'),
                                );
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              final List<Account> allAccountsFromStream =
                                  snapshot.data?.docs
                                      .map((doc) => Account.fromFirestore(doc))
                                      .toList() ??
                                  [];
                              List<Account> accountsToShow = [];
                              for (var accountOriginal
                                  in allAccountsFromStream) {
                                if (!accountOriginal.isRecurring) {
                                  if (!accountOriginal.isPaid &&
                                      !accountOriginal.dueDate.isBefore(
                                        nowOnly,
                                      ) &&
                                      !accountOriginal.dueDate.isAfter(
                                        tenDaysFromTodayEnd,
                                      )) {
                                    accountsToShow.add(accountOriginal);
                                  }
                                } else {
                                  DateTime? nextDueDate =
                                      accountOriginal
                                          .nextPotentialDueDateForRecurringMolde;
                                  if (nextDueDate != null &&
                                      !nextDueDate.isBefore(nowOnly) &&
                                      !nextDueDate.isAfter(
                                        tenDaysFromTodayEnd,
                                      )) {
                                    accountsToShow.add(
                                      accountOriginal.copyWith(
                                        dueDate: nextDueDate,
                                        isPaid: false,
                                      ),
                                    );
                                  }
                                }
                              }
                              accountsToShow.sort(
                                (a, b) => a.dueDate.compareTo(b.dueDate),
                              );
                              if (accountsToShow.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Nenhuma conta próxima do vencimento.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 2.0,
                                ),
                                itemCount: accountsToShow.length,
                                itemBuilder: (context, index) {
                                  final accountToDisplay =
                                      accountsToShow[index];
                                  final categoryIcon =
                                      _getCategoryIconForAccount(
                                        accountToDisplay.categoryId,
                                      );
                                  final accountDueDateOnly = DateTime(
                                    accountToDisplay.dueDate.year,
                                    accountToDisplay.dueDate.month,
                                    accountToDisplay.dueDate.day,
                                  );
                                  Account originalAccountForSelection =
                                      allAccountsFromStream.firstWhere(
                                        (a) => a.id == accountToDisplay.id,
                                        orElse: () => accountToDisplay,
                                      );
                                  bool isSelected = _selectedAccounts.any(
                                    (selectedAcc) =>
                                        selectedAcc.id ==
                                        originalAccountForSelection.id,
                                  );
                                  Color cardColor = Theme.of(context).cardColor;

                                  if (isSelected) {
                                    cardColor =
                                        (_selectionMode &&
                                                _blinkController.isAnimating)
                                            ? (_blinkColorAnimation.value ??
                                                Colors.blue.shade200)
                                            : Colors.blue.shade200;
                                  } else if (accountDueDateOnly
                                      .isAtSameMomentAs(nowOnly)) {
                                    cardColor = Colors.red.shade200;
                                  } else if (accountDueDateOnly
                                      .isAtSameMomentAs(tomorrowOnly)) {
                                    cardColor = Colors.yellow.shade300;
                                  }

                                  return GestureDetector(
                                    onLongPress:
                                        () => _toggleAccountSelection(
                                          originalAccountForSelection,
                                        ),

                                    onTap: () {
                                      if (_selectionMode) {
                                        _toggleAccountSelection(
                                          originalAccountForSelection,
                                        );
                                      } else {
                                        print(
                                          "Clique simples em: ${accountToDisplay.name} (Modo de seleção DESATIVADO)",
                                        );
                                      }
                                    },
                                    child: Card(
                                      elevation: 1.0,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 2.5,
                                        horizontal: 8.0,
                                      ),
                                      color: cardColor,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 4.0,
                                            ),
                                        leading: Icon(
                                          categoryIcon,
                                          size: 20,
                                          color:
                                              isSelected
                                                  ? Colors.blue.shade800
                                                  : Colors.blue,
                                        ),
                                        title: Text(
                                          accountToDisplay.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'Vence: ${DateFormat('dd/MM/yy').format(accountToDisplay.dueDate.toLocal())}' +
                                              (accountToDisplay.value != null
                                                  ? ' - R\$ ${accountToDisplay.value!.toStringAsFixed(2)}'
                                                  : '') +
                                              (accountToDisplay.isRecurring &&
                                                      !isSelected
                                                  ? ' (Mensal)'
                                                  : ''),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (!_selectionMode)
                          Container(
                            height: centralFloatingButtonsAreaHeight,
                            padding: const EdgeInsets.symmetric(vertical: 5.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FloatingActionButton(
                                      heroTag: 'vouPagarBtn_mainPage_col',
                                      onPressed: () {
                                        /* TODO: Ação */
                                      },
                                      backgroundColor: Colors.orange,
                                      shape: const CircleBorder(),
                                      child: const Icon(Icons.access_time),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vou Pagar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 120),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FloatingActionButton(
                                      heroTag: 'pagoBtn_mainPage_col',
                                      onPressed: () {
                                        /* TODO: Ação */
                                      },
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      child: const Icon(Icons.check),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pago',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: bottomFrameHeight),
                      ],
                    ),

                    if (_selectionMode)
                      Positioned(
                        bottom: bottomFrameHeight + 5,
                        left: 20,
                        right: 20,
                        height: selectionActionButtonsAreaHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withOpacity(0.97),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FloatingActionButton(
                                    heroTag: 'rescheduleSelectedBtn',
                                    onPressed:
                                        _selectedAccounts.isEmpty
                                            ? null
                                            : _scheduleNewDateForSelectedAccounts,
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    mini: true,
                                    shape: const CircleBorder(),
                                    child: const Icon(Icons.calendar_today),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Reagendar (${_selectedAccounts.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FloatingActionButton(
                                    heroTag: 'paySelectedBtn',
                                    onPressed:
                                        _selectedAccounts.isEmpty
                                            ? null
                                            : _markSelectedAccountsAsPaid,
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    mini: true,
                                    shape: const CircleBorder(),
                                    child: const Icon(Icons.check),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Pago (${_selectedAccounts.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endDocked,
              floatingActionButton: Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 20.0),
                child: FloatingActionButton(
                  heroTag: 'addCategoryBtn_mainPage',
                  onPressed: _showAddCategoryDialog,
                  backgroundColor: Colors.blue,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
