// lib/services/image_upload_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadProfileImage(File imageFile) async {
    User? user = _auth.currentUser;
    if (user == null) {
      print("Usuário não logado. Não é possível fazer upload de imagem.");
      return null;
    }

    try {
      Reference ref = _storage
          .ref()
          .child('profile_images')
          .child(user.uid + '.jpg');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      print("Upload de imagem de perfil concluído: $downloadUrl");
      return downloadUrl;
    } on FirebaseException catch (e) {
      print("Erro do Firebase ao fazer upload da imagem: ${e.message}");
      return null;
    } catch (e) {
      print("Erro inesperado ao fazer upload da imagem: $e");
      return null;
    }
  }

  // NOVO MÉTODO: deleteProfileImage
  Future<void> deleteProfileImage() async {
    User? user = _auth.currentUser;
    if (user == null || user.photoURL == null) {
      print("Nenhuma imagem de perfil para excluir no Firebase Storage.");
      return;
    }

    try {
      Reference ref = _storage.refFromURL(user.photoURL!);
      await ref.delete(); // Exclui a imagem do Storage
      await user.updatePhotoURL(null); // Remove a URL do perfil do Auth
      print(
        "Imagem de perfil excluída com sucesso do Firebase Storage e Auth.",
      );
    } on FirebaseException catch (e) {
      // Se a imagem já não existir no Storage, ele lançará um erro,
      // mas queremos apenas garantir que a photoURL seja removida do Auth.
      print(
        "Erro do Firebase ao excluir imagem (pode ser que já não exista): ${e.message}",
      );
      if (user.photoURL != null) {
        // Tenta remover a URL mesmo com erro no storage
        await user.updatePhotoURL(null);
      }
    } catch (e) {
      print("Erro inesperado ao excluir imagem: $e");
    }
  }
}
