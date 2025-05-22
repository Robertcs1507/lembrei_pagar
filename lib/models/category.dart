import 'account.dart'; // Importa a classe Account
import 'package:flutter/material.dart'; // Para IconData

class Category {
  String id; // << ADICIONADO: ID do documento no Firestore
  String name;
  IconData?
  icon; // << Certifique-se de que seu modelo tem campo para ícone se estiver salvando
  final List<Account> accounts =
      []; // Lista de contas associadas a esta categoria

  // Adicionado 'id' ao construtor
  Category({required this.id, required this.name, this.icon});
}
