import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/auth_gate.dart';
import 'services/notification_service.dart';
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // REMOVIDO POR ENQUANTO
// import 'dart:io'; // REMOVIDO POR ENQUANTO

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  // A inicialização do AndroidAlarmManager foi REMOVIDA por enquanto.
  // if (!kIsWeb && Platform.isAndroid) {
  //   try {
  //     await AndroidAlarmManager.initialize();
  //     print("AndroidAlarmManager inicializado com sucesso.");
  //   } catch (e) {
  //     print("Erro ao inicializar AndroidAlarmManager: $e");
  //   }
  // }

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
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
