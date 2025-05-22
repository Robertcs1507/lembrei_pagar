import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/auth_gate.dart';
import 'services/notification_service.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'dart:io'; // Para Platform.isAndroid
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializa notificações locais
  final NotificationService notificationService = NotificationService();
  await notificationService.initializeNotifications((
    NotificationResponse response,
  ) async {
    final String? payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      debugPrint('main.dart: Notificação clicada com payload: $payload');
      // navigatorKey.currentState?.pushNamed('/detalhes_conta', arguments: payload);
    }
  });
  await notificationService.requestPermissions();

  // Inicializa o AndroidAlarmManager apenas se for Android (e não Web)
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
      print("✅ AndroidAlarmManager inicializado com sucesso em main.dart.");
    } catch (e) {
      print("❌ Erro ao inicializar AndroidAlarmManager em main.dart: $e");
    }
  } else {
    print(
      "ℹ️ AndroidAlarmManager não inicializado (plataforma não suportada).",
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lembrei de Pagar',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.blueAccent,
          onSecondary: Colors.white,
        ),
        primaryColor: Colors.blue,
        primaryColorDark: Colors.blue[700],
        primaryColorLight: Colors.blue[100],
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
        ),
        inputDecorationTheme: InputDecorationTheme(
          prefixIconColor: Colors.blue[600],
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: Colors.blue.withOpacity(0.04),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
