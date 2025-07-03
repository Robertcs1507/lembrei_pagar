// lib/screens/reports_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';

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
  Map<String, double> _categoryAmounts = {};

  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (_currentFilter == ReportFilter.weekly ||
        _currentFilter == ReportFilter.monthly) {
      _selectedDate = DateTime.now();
    }
    _applyFilter();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    List<Account> tempAccounts = [];
    double tempTotal = 0.0;
    Map<String, double> tempCategoryAmounts = {};

    for (var cat in widget.categories) {
      tempCategoryAmounts[cat.id] = 0.0;
    }
    tempCategoryAmounts['no_category'] = 0.0;

    for (var account in widget.paidAccounts) {
      if (!account.isPaid || (account.value ?? 0.0) <= 0) {
        continue;
      }

      final DateTime effectiveDate =
          account.paidDate?.toLocal() ?? account.dueDate.toLocal();
      bool matchesCurrentFilterCriteria = false;

      if (_currentFilter == ReportFilter.category) {
        if (_selectedCategory != null) {
          matchesCurrentFilterCriteria =
              (account.categoryId == _selectedCategory!.id);
        } else {
          matchesCurrentFilterCriteria = true;
        }
      } else {
        switch (_currentFilter) {
          case ReportFilter.daily:
            matchesCurrentFilterCriteria = DateUtils.isSameDay(
              effectiveDate,
              _selectedDate,
            );
            break;
          case ReportFilter.weekly:
            final DateTime startOfWeek = _selectedDate
                .subtract(Duration(days: _selectedDate.weekday - 1))
                .copyWith(
                  hour: 0,
                  minute: 0,
                  second: 0,
                  millisecond: 0,
                  microsecond: 0,
                );
            final DateTime endOfWeek = startOfWeek
                .add(const Duration(days: 6))
                .copyWith(
                  hour: 23,
                  minute: 59,
                  second: 59,
                  millisecond: 999,
                  microsecond: 999,
                );
            matchesCurrentFilterCriteria =
                !effectiveDate.isBefore(startOfWeek) &&
                !effectiveDate.isAfter(endOfWeek);
            break;
          case ReportFilter.monthly:
            matchesCurrentFilterCriteria =
                effectiveDate.year == _selectedDate.year &&
                effectiveDate.month == _selectedDate.month;
            break;
          case ReportFilter.allTime:
            matchesCurrentFilterCriteria = true;
            break;
          case ReportFilter.category:
            break;
        }
      }

      if (matchesCurrentFilterCriteria) {
        tempAccounts.add(account);
        tempTotal += account.value ?? 0.0;

        final String categoryKey =
            account.categoryId.isNotEmpty &&
                    widget.categories.any((cat) => cat.id == account.categoryId)
                ? account.categoryId
                : 'no_category';
        tempCategoryAmounts[categoryKey] =
            (tempCategoryAmounts[categoryKey] ?? 0.0) + (account.value ?? 0.0);
      }
    }

    tempAccounts.sort(
      (a, b) => (a.paidDate ?? a.dueDate).compareTo(b.paidDate ?? b.dueDate),
    );

    setState(() {
      _filteredAccounts = tempAccounts;
      _totalFilteredAmount = tempTotal;
      _categoryAmounts = Map.fromEntries(
        tempCategoryAmounts.entries.where((entry) => entry.value > 0),
      );
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

  List<PieChartSectionData> _showingSections() {
    if (_totalFilteredAmount <= 0 || _categoryAmounts.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 100,
          title: 'Nenhum dado',
          radius: 60,
          titleStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
          titlePositionPercentageOffset: 0.55,
        ),
      ];
    }

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    final List<Color> pieColors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.brown.shade600,
      Colors.cyan.shade600,
      Colors.lime.shade600,
      Colors.pink.shade600,
    ];

    final sortedCategoryAmounts =
        _categoryAmounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedCategoryAmounts) {
      final categoryId = entry.key;
      final amount = entry.value;

      if (amount <= 0) continue;

      final category = widget.categories.firstWhereOrNull(
        (cat) => cat.id == categoryId,
      );
      final String categoryDisplayName =
          category?.name ??
          (categoryId == 'no_category' ? 'Sem Categoria' : 'Desconhecida');
      final IconData categoryDisplayIcon =
          category?.icon ??
          (categoryId == 'no_category' ? Icons.label_off : Icons.help_outline);

      final double percentage = (amount / _totalFilteredAmount) * 100;
      final bool isTouched = false;
      final double radius = isTouched ? 60 : 50;
      final double titleFontSize = percentage < 5 && percentage > 0 ? 8 : 12;

      sections.add(
        PieChartSectionData(
          color: pieColors[colorIndex % pieColors.length],
          value: percentage,
          title: percentage > 0 ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: radius,
          titleStyle: GoogleFonts.poppins(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: Transform.scale(
            scale: percentage > 0 ? 1 : 0,
            child: _buildBadge(categoryDisplayIcon, Colors.white),
          ),
          badgePositionPercentageOffset: 0.98,
        ),
      );
      colorIndex++;
    }
    return sections;
  }

  Widget _buildBadge(IconData iconData, Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        // Removido o boxShadow para eliminar a bolinha branca
      ),
      child: Center(child: Icon(iconData, size: 12, color: color)),
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
          // Seção de Filtros e Resumo
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

          // Seção do Gráfico e Legenda
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Distribuição por Categoria',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 170, // Altura fixa para o container
                  child: Stack(
                    children: [
                      // Legenda à esquerda
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(
                          width:
                              MediaQuery.of(context).size.width *
                              0.45, // 45% da largura
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  _categoryAmounts.entries.map<Widget>((entry) {
                                    final categoryId = entry.key;
                                    final amount = entry.value;
                                    final category = widget.categories
                                        .firstWhereOrNull(
                                          (cat) => cat.id == categoryId,
                                        );
                                    final String categoryDisplayName =
                                        category?.name ??
                                        (categoryId == 'no_category'
                                            ? 'Sem Categoria'
                                            : 'Desconhecida');

                                    final keysList =
                                        _categoryAmounts.keys.toList();
                                    final int index = keysList.indexOf(
                                      categoryId,
                                    );
                                    final List<Color> pieColors = [
                                      Colors.blue.shade600,
                                      Colors.green.shade600,
                                      Colors.orange.shade600,
                                      Colors.purple.shade600,
                                      Colors.red.shade600,
                                      Colors.teal.shade600,
                                      Colors.indigo.shade600,
                                      Colors.brown.shade600,
                                      Colors.cyan.shade600,
                                      Colors.lime.shade600,
                                      Colors.pink.shade600,
                                    ];
                                    final Color legendColor =
                                        pieColors[index % pieColors.length];

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: legendColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '$categoryDisplayName: R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '').format(amount)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey[800],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ),

                      // Gráfico centralizado
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child:
                                _totalFilteredAmount > 0 &&
                                        _categoryAmounts.isNotEmpty
                                    ? PieChart(
                                      PieChartData(
                                        sections: _showingSections(),
                                        centerSpaceRadius: 35,
                                        sectionsSpace: 1,
                                        startDegreeOffset: -90,
                                        pieTouchData: PieTouchData(
                                          touchCallback: (
                                            FlTouchEvent event,
                                            pieTouchResponse,
                                          ) {
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    )
                                    : Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Nenhum dado para exibir',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de contas
          Expanded(
            flex: 3,
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
                      thumbVisibility: true,
                      controller: _listScrollController,
                      child: ListView.builder(
                        controller: _listScrollController,
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
