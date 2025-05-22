// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print(
          "AUTH_GATE: Connection State: ${snapshot.connectionState}",
        ); // DEBUG
        if (snapshot.connectionState == ConnectionState.waiting) {
          print("AUTH_GATE: Waiting for auth state..."); // DEBUG
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print("AUTH_GATE: Error in auth state: ${snapshot.error}"); // DEBUG
          return const Scaffold(
            body: Center(child: Text("Erro na autenticação")),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          print("AUTH_GATE: No user data, navigating to LoginPage."); // DEBUG
          return const LoginPage();
        }

        print(
          "AUTH_GATE: User is logged in (UID: ${snapshot.data!.uid}), navigating to HomePage.",
        ); // DEBUG
        return const HomePage();
      },
    );
  }
}
