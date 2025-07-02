import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Cabeçalho
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[50]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.wallet_giftcard_rounded,
                  color: Colors.blue[600],
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  'Lembrei de Pagar',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Menu',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Início
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
            onTap: () {
              Navigator.pop(context);
              // Navegar para a página inicial
            },
          ),

          // Categorias
          ExpansionTile(
            leading: Icon(Icons.category, color: Colors.blue[600]),
            title: Text(
              'Categorias',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            children: [
              _buildCategoryTile(context, 'Estudos', Icons.school),
              _buildCategoryTile(context, 'Lazer', Icons.event),
              _buildCategoryTile(context, 'Trabalho', Icons.work),
              _buildCategoryTile(context, 'Casa', Icons.home),
              _buildCategoryTile(context, 'Teste', Icons.home),
            ],
          ),

          // Relatórios
          ListTile(
            leading: Icon(Icons.bar_chart, color: Colors.blue[600]),
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
              // Navegar para Relatórios
            },
          ),

          // Sobre
          ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blue[600]),
            title: Text(
              'Sobre',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              // Navegar para Sobre
            },
          ),

          const Spacer(),

          // Sair
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
              // Lógica de logout
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[400]),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        // Navegar para a categoria selecionada
      },
    );
  }
}
