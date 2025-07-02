import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart'; // Adicionado para Firestore

import '../services/image_upload_service.dart'; // Importe seu serviço de upload de imagem

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();

  // Controlador para o campo de texto do nome de exibição
  late TextEditingController _displayNameController;

  // Lista de ícones de avatar predefinidos
  final List<IconData> _predefinedAvatars = [
    Icons.person,
    Icons.face,
    Icons.sentiment_satisfied_alt,
    Icons.pets,
    Icons.rocket_launch,
    Icons.cake,
    Icons.lightbulb,
    Icons.umbrella,
    Icons.android, // Mais um ícone
  ];

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: _auth.currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  // Função para selecionar imagem da galeria
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File imageFile = File(image.path);
      try {
        String? photoUrl = await _imageUploadService.uploadProfileImage(
          imageFile,
        );
        if (mounted) {
          if (photoUrl != null) {
            // Se uma foto foi carregada, limpa qualquer ícone salvo no Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .update({
                  'avatarIconCodePoint': FieldValue.delete(),
                  'avatarIconFontFamily': FieldValue.delete(),
                  'avatarIconFontPackage': FieldValue.delete(),
                });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto de perfil atualizada com sucesso!'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Falha ao fazer upload da foto.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao escolher/enviar imagem: $e')),
          );
        }
      }
    }
  }

  // Função para remover a imagem de perfil
  Future<void> _removeImage() async {
    User? currentUser = _auth.currentUser;
    if (currentUser?.photoURL == null &&
        !(await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser?.uid)
                .get())
            .data()!
            .containsKey('avatarIconCodePoint')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma foto ou ícone de perfil para remover.'),
          ),
        );
      }
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remover Foto/Ícone de Perfil?'),
          content: const Text(
            'Tem certeza que deseja remover sua foto/ícone de perfil atual?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Remover', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        if (currentUser?.photoURL != null) {
          await _imageUploadService
              .deleteProfileImage(); // Remove do Storage e limpa photoURL no Auth
        }
        // Limpa o ícone salvo no Firestore, se houver
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({
              'avatarIconCodePoint': FieldValue.delete(),
              'avatarIconFontFamily': FieldValue.delete(),
              'avatarIconFontPackage': FieldValue.delete(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto/ícone de perfil removido.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao remover foto/ícone: $e')),
          );
        }
      }
    }
  }

  // Função para atualizar o nome de exibição
  Future<void> _updateDisplayName(User? currentUser) async {
    if (currentUser == null) return;
    final newName = _displayNameController.text.trim();
    if (newName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O nome de exibição não pode ser vazio.'),
          ),
        );
      }
      return;
    }
    if (newName == currentUser.displayName) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('O nome já é este.')));
      }
      return;
    }

    try {
      await currentUser.updateDisplayName(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nome atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar nome: $e')));
      }
    }
  }

  // Função para selecionar um ícone predefinido
  Future<void> _selectPredefinedIcon(
    IconData iconData,
    User? currentUser,
  ) async {
    if (currentUser == null) return;

    try {
      // 1. Remove qualquer foto de perfil existente do Firebase Auth e Storage
      if (currentUser.photoURL != null) {
        await _imageUploadService.deleteProfileImage();
      }

      // 2. Salva os detalhes do ícone no Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
            'avatarIconCodePoint': iconData.codePoint,
            'avatarIconFontFamily': iconData.fontFamily,
            'avatarIconFontPackage': iconData.fontPackage,
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ícone de avatar salvo com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar ícone: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos StreamBuilder para observar as mudanças no perfil do usuário em tempo real
    return StreamBuilder<User?>(
      stream: _auth.userChanges(), // Observa as mudanças no usuário logado
      builder: (context, snapshot) {
        User? currentUser = snapshot.data; // Pega o usuário mais atualizado

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
          builder: (context, iconSnapshot) {
            IconData? displayIcon = Icons.person; // Ícone padrão
            if (iconSnapshot.hasData &&
                iconSnapshot.data != null &&
                iconSnapshot.data!.exists) {
              Map<String, dynamic> userData = iconSnapshot.data!.data()!;
              int? codePoint = userData['avatarIconCodePoint'];
              String? fontFamily = userData['avatarIconFontFamily'];
              String? fontPackage = userData['avatarIconFontPackage'];

              if (codePoint != null && fontFamily != null) {
                displayIcon = IconData(
                  codePoint,
                  fontFamily: fontFamily,
                  fontPackage: fontPackage,
                );
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: Text('Editar Perfil', style: GoogleFonts.poppins()),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap:
                            _pickImage, // Tenta escolher nova imagem ao tocar no avatar
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage:
                              currentUser?.photoURL != null
                                  ? NetworkImage(currentUser!.photoURL!)
                                  : null,
                          child:
                              currentUser?.photoURL == null
                                  ? Icon(
                                    displayIcon, // Usa o ícone salvo no Firestore ou o padrão
                                    size: 70,
                                    color: Colors.blue.shade400,
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Escolher Foto'),
                          ),
                          if (currentUser?.photoURL != null ||
                              (iconSnapshot.hasData &&
                                  iconSnapshot.data!.exists &&
                                  iconSnapshot.data!.data()!.containsKey(
                                    'avatarIconCodePoint',
                                  )))
                            const SizedBox(width: 10),
                          if (currentUser?.photoURL != null ||
                              (iconSnapshot.hasData &&
                                  iconSnapshot.data!.exists &&
                                  iconSnapshot.data!.data()!.containsKey(
                                    'avatarIconCodePoint',
                                  )))
                            ElevatedButton.icon(
                              onPressed: _removeImage,
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Remover Foto/Ícone',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor:
                                    Colors
                                        .red, // Define a cor do texto do botão para vermelho
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Selecione um Avatar Predefinido (se não houver foto):',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        alignment: WrapAlignment.center,
                        children:
                            _predefinedAvatars.map((icon) {
                              // Determina se este ícone está atualmente selecionado (baseado no Firestore)
                              bool isSelected =
                                  (iconSnapshot.hasData &&
                                      iconSnapshot.data!.exists) &&
                                  iconSnapshot.data!
                                          .data()!['avatarIconCodePoint'] ==
                                      icon.codePoint &&
                                  iconSnapshot.data!
                                          .data()!['avatarIconFontFamily'] ==
                                      icon.fontFamily;

                              return GestureDetector(
                                onTap:
                                    () => _selectPredefinedIcon(
                                      icon,
                                      currentUser,
                                    ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor:
                                      isSelected
                                          ? Colors.blue.shade200
                                          : Colors.grey.shade200,
                                  child: Icon(
                                    icon,
                                    size: 30,
                                    color:
                                        isSelected
                                            ? Colors.blue.shade800
                                            : Colors.grey.shade700,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: InputDecoration(
                          labelText: 'Nome de Exibição',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        onFieldSubmitted:
                            (value) => _updateDisplayName(currentUser),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Email: ${currentUser?.email ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
