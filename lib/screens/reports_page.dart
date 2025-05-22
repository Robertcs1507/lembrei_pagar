// In your file lib/screens/reports_page.dart

import 'package:flutter/material.dart';
import '../models/account.dart'; // Make sure the path to your Account model is correct
import '../models/category.dart'; // Make sure the path to your Category model is correct
import 'package:intl/intl.dart'; // Import DateFormat
import 'package:collection/collection.dart'; // Import collection for firstWhereOrNull

class ReportsPage extends StatefulWidget {
  final List<Account> paidAccounts;
  final List<Category>
  categories; // Passamos as categorias para poder filtrar por elas

  const ReportsPage({
    Key? key,
    required this.paidAccounts,
    required this.categories, // Recebe as categorias
  }) : super(key: key);

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Variáveis de estado para as opções de filtragem selecionadas
  String _selectedFilter = 'Mês'; // Filtro padrão ao abrir a página
  DateTime _selectedDate =
      DateTime.now(); // Data padrão para filtros baseados em tempo
  Category?
  _selectedCategory; // Categoria selecionada para o filtro por categoria

  // Lista para armazenar as contas filtradas e o total
  List<Account> _filteredAccounts = [];
  double _totalFilteredValue = 0.0;

  @override
  void initState() {
    super.initState();
    // Aplica o filtro inicial quando a página carrega (usando o filtro padrão e a data/categoria padrão)
    _applyFilter();
  }

  // Método para aplicar o filtro selecionado e atualizar a lista e o total
  void _applyFilter() {
    List<Account> filteredList = [];
    double total = 0.0;

    // Lógica de filtragem baseada no filtro selecionado (_selectedFilter)
    if (_selectedFilter == 'Mês') {
      // Filtra por mês e ano da data selecionada
      filteredList =
          widget.paidAccounts.where((account) {
            // Compara apenas o ano e o mês da data de vencimento (que agora representa a data de pagamento)
            // Note que a data de vencimento aqui está sendo usada como a data que a conta foi marcada como paga
            return account.dueDate.year == _selectedDate.year &&
                account.dueDate.month == _selectedDate.month;
          }).toList();
    } else if (_selectedFilter == 'Semana') {
      // Filtra pela semana que contém a data selecionada (_selectedDate)
      // Calcula o início e o fim da semana (considerando segunda como primeiro dia)
      final startOfWeek = _selectedDate.subtract(
        Duration(days: _selectedDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      filteredList =
          widget.paidAccounts.where((account) {
            // Cria uma data com apenas dia, mês e ano para a comparação
            final accountDateOnly = DateTime(
              account.dueDate.year,
              account.dueDate.month,
              account.dueDate.day,
            );
            // Verifica se a data da conta está dentro da semana (inclusive)
            return accountDateOnly.isAfter(
                  startOfWeek.subtract(const Duration(days: 1)),
                ) && // Verifica se é depois do dia anterior ao início da semana
                accountDateOnly.isBefore(
                  endOfWeek.add(const Duration(days: 1)),
                ); // Verifica se é antes do dia seguinte ao fim da semana
          }).toList();
    } else if (_selectedFilter == 'Dia') {
      // Filtra por dia da data selecionada
      filteredList =
          widget.paidAccounts.where((account) {
            // Cria uma data com apenas dia, mês e ano para a comparação
            final accountDateOnly = DateTime(
              account.dueDate.year,
              account.dueDate.month,
              account.dueDate.day,
            );
            final selectedDateOnly = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            );
            return accountDateOnly.isAtSameMomentAs(selectedDateOnly);
          }).toList();
    } else if (_selectedFilter == 'Categoria') {
      // *** Lógica CORRIGIDA para filtrar por categoria selecionada ***
      if (_selectedCategory != null) {
        // Filtra contas pagas verificando se a conta pertence à lista de contas da categoria selecionada.
        // Isso depende de sua classe Category ter uma propriedade que seja uma lista de Accounts (ex: 'accounts')
        // E da classe Account ter ==/hashCode correto (baseado no ID único).
        filteredList =
            widget.paidAccounts.where((paidAccount) {
              // Obtém a categoria da conta paga usando o helper
              final accountCategory = _getCategoryForAccount(paidAccount);
              // Inclui a conta se a categoria foi encontrada E é a categoria selecionada
              // A comparação aqui usa o objeto Category diretamente ou um ID, dependendo de como você implementou Category ==
              return accountCategory != null &&
                  accountCategory ==
                      _selectedCategory; // Compara objetos Category (requer Category sobrescrevendo ==/hashCode)
              // Ou se Category tiver apenas ID e Account tiver categoryId:
              // return paidAccount.categoryId != null && paidAccount.categoryId == _selectedCategory!.id;
            }).toList();
      } else {
        // Se 'Todas as Categorias' for selecionado (_selectedCategory é null)
        filteredList = widget.paidAccounts; // Mostra todas as contas pagas
      }
    } else if (_selectedFilter == 'Todos') {
      // 'Todos' filter, show all paid accounts
      filteredList = widget.paidAccounts;
    }

    // Calcula o total dos valores das contas filtradas
    for (var account in filteredList) {
      total +=
          account.value ?? 0.0; // Sum the value (uses 0.0 if value is null)
    }

    // Sort the filtered list by date (optional, but good for reports)
    filteredList.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // Update the state with the filtered list and the total
    setState(() {
      _filteredAccounts = filteredList;
      _totalFilteredValue = total;
    });
  }

  // Helper method to get the category for a given account
  // Iterates through categories to find the one containing the account.
  Category? _getCategoryForAccount(Account account) {
    // *** Implementação do Helper ***
    // Encontra a categoria dentro da lista de categorias passada que contém esta conta.
    // Requer que a classe Category tenha uma propriedade que seja uma lista de Accounts (ex: 'accounts')
    // e que a classe Account tenha o ==/hashCode correto (baseado no ID único).
    return widget.categories.firstWhereOrNull(
      (cat) => cat.accounts.contains(account),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios de Contas Pagas')),
      body: Column(
        // Use Column for vertical layout
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // Stretch children horizontally
        children: [
          // Filter Selection Section
          Padding(
            padding: const EdgeInsets.all(
              16.0,
            ), // Aplica 16.0 de padding em todos os lados
            child: Column(
              // Column for vertical layout of filter options
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar por:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ), // Highlight "Filter by" text
                ),
                const SizedBox(height: 8),
                // Dropdown para selecionar o tipo de filtro (Dia, Semana, Mês, Categoria, Todos)
                DropdownButton<String>(
                  isExpanded: true, // Faz o dropdown ocupar o espaço disponível
                  value: _selectedFilter,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedFilter = newValue;
                        // Reinicia os critérios de filtro quando o tipo de filtro muda
                        _selectedDate =
                            DateTime.now(); // Volta para a data atual
                        _selectedCategory =
                            null; // Limpa a categoria selecionada
                        _applyFilter(); // Aplica o filtro com os critérios reiniciados (ou padrão)
                      });
                    }
                  },
                  items:
                      <String>[
                        'Dia',
                        'Semana',
                        'Mês',
                        'Categoria',
                        'Todos',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                // Interface para selecionar o critério específico do filtro (Data ou Categoria)
                if (_selectedFilter == 'Dia' ||
                    _selectedFilter == 'Semana' ||
                    _selectedFilter == 'Mês')
                  Row(
                    // Row para alinhar o texto da data e o botão do seletor
                    children: [
                      Expanded(
                        // Permite que o texto da data ocupe o espaço disponível
                        child: Text(
                          'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}', // Exibe a data selecionada formatada
                          style: const TextStyle(
                            fontSize: 16,
                          ), // Tamanho da fonte para o texto da data
                        ),
                      ),
                      IconButton(
                        // Botão para abrir o seletor de data
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          // Mostra o seletor de data
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                _selectedDate, // Data inicial no seletor é a data atualmente selecionada
                            firstDate: DateTime(
                              2000,
                            ), // Data mais antiga selecionável (ajuste conforme a data da sua conta mais antiga)
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ), // Permite selecionar até um ano no futuro (ajuste se necessário)
                          );
                          // Se uma data foi selecionada e é diferente da data atual
                          if (pickedDate != null &&
                              pickedDate != _selectedDate) {
                            setState(() {
                              _selectedDate =
                                  pickedDate; // Atualiza a data selecionada
                              _applyFilter(); // Aplica o filtro com a nova data
                            });
                          }
                        },
                      ),
                    ],
                  ),
                if (_selectedFilter == 'Categoria')
                  Row(
                    // Row para alinhar o dropdown de categoria
                    children: [
                      Expanded(
                        // Permite que o dropdown ocupe o espaço disponível
                        child: DropdownButton<Category>(
                          isExpanded:
                              true, // Faz o dropdown ocupar o espaço disponível
                          value: _selectedCategory,
                          hint: const Text(
                            'Selecione uma Categoria',
                          ), // Texto exibido quando nada está selecionado
                          onChanged: (Category? newValue) {
                            setState(() {
                              _selectedCategory =
                                  newValue; // Atualiza a categoria selecionada
                              _applyFilter(); // Aplica o filtro com a nova categoria
                            });
                          },
                          items: [
                            // Lista de opções do dropdown
                            DropdownMenuItem<Category>(
                              value:
                                  null, // Opção para 'Todas as Categorias' (valor null)
                              child: const Text('Todas as Categorias'),
                            ),
                            // Mapeia a lista de categorias disponíveis para DropdownMenuItems
                            // Use category.name.toUpperCase() if you want uppercase in the dropdown
                            ...widget.categories.map<
                              DropdownMenuItem<Category>
                            >((Category category) {
                              return DropdownMenuItem<Category>(
                                value: category, // O valor é o objeto Category
                                child: Text(
                                  category.name,
                                ), // O texto exibido no dropdown é o nome da categoria
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Seção de Resumo (Total Pago)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Pago${_selectedFilter != 'Todos' ? ' neste ${_selectedFilter.toLowerCase()}' : ''}: R\$ ${_totalFilteredValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ), // Destaca o total
            ),
          ),
          // Seção da Lista de Contas Filtradas
          Expanded(
            // Permite que a lista ocupe o espaço restante
            child: ListView.builder(
              itemCount:
                  _filteredAccounts
                      .length, // Quantidade de itens na lista filtrada
              itemBuilder: (context, index) {
                // Constrói cada item da lista
                final account = _filteredAccounts[index];
                // Exemplo de ListTile com ícone e nome da categoria
                final categoryForAccount = _getCategoryForAccount(
                  account,
                ); // Obtém a categoria da conta

                return ListTile(
                  leading: Icon(
                    // Ícone da categoria (se encontrada)
                    categoryForAccount?.icon ??
                        Icons
                            .receipt, // Usa o ícone da categoria ou um ícone genérico
                    color: Colors.blue, // Cor do ícone
                  ),
                  title: Text(account.name), // Nome da conta
                  subtitle: Text(
                    // Data de pagamento (usando dueDate como placeholder) e valor
                    'Pago em: ${DateFormat('dd/MM/yyyy').format(account.dueDate.toLocal())}' + // Assume que dueDate agora representa a data de pagamento para contas nesta lista
                        (account.value != null
                            ? ' - R\$ ${account.value!.toStringAsFixed(2)}'
                            : ''), // Exibe o valor se não for null
                  ),
                  trailing: Text(
                    // Nome da categoria (se encontrada)
                    categoryForAccount?.name ?? 'Sem Categoria',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
