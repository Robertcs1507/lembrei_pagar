// lib/screens/reports_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../models/account.dart';
import '../models/category.dart';

enum ReportFilter { daily, weekly, monthly, category, allTime }

class ReportsPage extends StatefulWidget {
  final List<Account> paidAccounts;
  final List<Category> categories;

  const ReportsPage({
    Key? key,
    required this.paidAccounts,
    required this.categories,
  }) : super(key: key);

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportFilter _currentFilter = ReportFilter.monthly;
  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;

  List<Account> _filteredAccounts = [];
  double _totalFilteredAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  void _applyFilter() {
    List<Account> tempAccounts = [];
    double tempTotal = 0.0;

    for (var account in widget.paidAccounts) {
      final DateTime effectiveDate =
          account.paidDate?.toLocal() ?? account.dueDate.toLocal();

      if (_currentFilter == ReportFilter.category) {
        if (_selectedCategory != null) {
          if (account.categoryId == _selectedCategory!.id) {
            tempAccounts.add(account);
            tempTotal += account.value ?? 0.0;
          }
        } else {
          tempAccounts.add(account);
          tempTotal += account.value ?? 0.0;
        }
        continue;
      }

      bool matchesPeriod = false;

      switch (_currentFilter) {
        case ReportFilter.daily:
          matchesPeriod = DateUtils.isSameDay(effectiveDate, _selectedDate);
          break;
        case ReportFilter.weekly:
          final DateTime startOfWeek = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1),
          );
          final DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
          matchesPeriod =
              !effectiveDate.isBefore(startOfWeek) &&
              !effectiveDate.isAfter(endOfWeek);
          break;
        case ReportFilter.monthly:
          matchesPeriod =
              effectiveDate.year == _selectedDate.year &&
              effectiveDate.month == _selectedDate.month;
          break;
        case ReportFilter.allTime:
          matchesPeriod = true;
          break;
        case ReportFilter.category:
          break;
      }

      if (matchesPeriod) {
        tempAccounts.add(account);
        tempTotal += account.value ?? 0.0;
      }
    }

    tempAccounts.sort(
      (a, b) => (a.paidDate ?? a.dueDate).compareTo(b.paidDate ?? b.dueDate),
    );

    setState(() {
      _filteredAccounts = tempAccounts;
      _totalFilteredAmount = tempTotal;
    });
  }

  String _getFilterPeriodTitle() {
    switch (_currentFilter) {
      case ReportFilter.daily:
        return 'Relatório Diário: ${DateFormat('dd/MM/yyyy').format(_selectedDate.toLocal())}';
      case ReportFilter.weekly:
        final DateTime startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        return 'Relatório Semanal: ${DateFormat('dd/MM').format(startOfWeek.toLocal())} - ${DateFormat('dd/MM').format(endOfWeek.toLocal())}';
      case ReportFilter.monthly:
        return 'Relatório Mensal: ${DateFormat('MM/yyyy').format(_selectedDate.toLocal())}';
      case ReportFilter.category:
        return 'Relatório por Categoria: ${_selectedCategory?.name ?? 'Todas as Categorias'}';
      case ReportFilter.allTime:
        return 'Relatório Geral: Todas as Contas Pagas';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _applyFilter();
      });
    }
  }

  void _selectCategory() {
    showDialog<Category?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Selecionar Categoria', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Todas as Categorias',
                    style: GoogleFonts.poppins(),
                  ),
                  onTap: () {
                    Navigator.pop(context, null);
                  },
                ),
                ...widget.categories
                    .map(
                      (category) => ListTile(
                        title: Text(
                          category.name.isNotEmpty
                              ? (category.name[0].toUpperCase() +
                                  category.name.substring(1).toLowerCase())
                              : 'Categoria S/ Nome',
                          style: GoogleFonts.poppins(),
                        ),
                        onTap: () {
                          Navigator.pop(context, category);
                        },
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        );
      },
    ).then((selectedCategory) {
      if (selectedCategory != null || _selectedCategory != null) {
        setState(() {
          _selectedCategory = selectedCategory;
          _currentFilter = ReportFilter.category;
          _applyFilter();
        });
      }
    });
  }

  Category? _getCategoryForAccount(Account account) {
    return widget.categories.firstWhereOrNull(
      (cat) => cat.id == account.categoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatórios de Pagamentos', style: GoogleFonts.poppins()),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8.0,
                  alignment: WrapAlignment.center,
                  children:
                      ReportFilter.values.map((filter) {
                        String label = '';
                        switch (filter) {
                          case ReportFilter.daily:
                            label = 'Dia';
                            break;
                          case ReportFilter.weekly:
                            label = 'Semana';
                            break;
                          case ReportFilter.monthly:
                            label = 'Mês';
                            break;
                          case ReportFilter.category:
                            label = 'Categoria';
                            break;
                          case ReportFilter.allTime:
                            label = 'Tudo';
                            break;
                        }
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: GoogleFonts.poppins(
                              color:
                                  _currentFilter == filter
                                      ? Colors.white
                                      : Colors.blueGrey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: _currentFilter == filter,
                          selectedColor: Colors.blue[600],
                          backgroundColor: Colors.grey[200],
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _currentFilter = filter;
                                if (filter != ReportFilter.category) {
                                  _selectedCategory = null;
                                }
                                _applyFilter();
                              });
                            }
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (_currentFilter == ReportFilter.daily ||
                        _currentFilter == ReportFilter.weekly ||
                        _currentFilter == ReportFilter.monthly)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            'Selecionar Data',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      ),
                    if (_currentFilter == ReportFilter.category)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectCategory,
                          icon: const Icon(Icons.category),
                          label: Text(
                            'Selecionar Categoria',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  _getFilterPeriodTitle(),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Pago: R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '').format(_totalFilteredAmount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 24, thickness: 1),
              ],
            ),
          ),

          // Lista de contas pagas filtradas com Scrollbar
          Expanded(
            child:
                _filteredAccounts.isEmpty
                    ? Center(
                      child: Text(
                        'Nenhuma conta paga encontrada para este filtro.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : Scrollbar(
                      // Adicionado o widget Scrollbar aqui
                      thumbVisibility:
                          true, // Garante que a barra de rolagem seja sempre visível
                      child: ListView.builder(
                        itemCount: _filteredAccounts.length,
                        itemBuilder: (context, index) {
                          final account = _filteredAccounts[index];
                          final category = _getCategoryForAccount(account);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            elevation: 1,
                            child: ListTile(
                              leading: Icon(
                                category?.icon ?? Icons.label_off,
                                color: Colors.green[400],
                              ),
                              title: Text(
                                account.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${DateFormat('dd/MM/yyyy').format(account.paidDate?.toLocal() ?? account.dueDate.toLocal())} - ${category?.name ?? 'Sem Categoria'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: Text(
                                'R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '').format(account.value ?? 0.0)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
