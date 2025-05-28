// lib/services/notification_service.dart
import 'package:flutter/foundation.dart'; // Para debugPrint e kIsWeb
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Imports do Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< ADICIONADO para Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <<< ADICIONADO para Firebase Auth

// Ajuste o caminho se o nome do seu pacote for diferente de 'lembrei_pegar'
import 'package:lembrei_pegar/firebase_options.dart';

// HANDLER PARA MENSAGENS FCM EM BACKGROUND (PRECISA SER TOP-LEVEL OU STATIC)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "Handler (FCM background): Mensagem recebida: ${message.messageId}",
  );
  debugPrint("Handler (FCM background): Dados da mensagem: ${message.data}");

  if (message.notification != null) {
    debugPrint(
      "Handler (FCM background): Notificação: ${message.notification?.title} - ${message.notification?.body}",
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _localNotificationsInitialized = false;
  bool _fcmInitialized = false;

  Function(NotificationResponse)?
  _onDidReceiveLocalNotificationResponseCallback;

  Future<void> initialize(
    Function(NotificationResponse)?
    onDidReceiveLocalNotificationResponseCallback,
  ) async {
    _onDidReceiveLocalNotificationResponseCallback =
        onDidReceiveLocalNotificationResponseCallback;

    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
    }

    if (!_fcmInitialized) {
      await _initializeFirebaseMessaging();
    }
  }

  Future<void> _initializeLocalNotifications() async {
    debugPrint("Inicializando Notificações Locais...");
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          onDidReceiveLocalNotification: _onDidReceiveIOSLocalNotification,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
          "onDidReceiveNotificationResponse (local): payload: ${response.payload}",
        );
        _onDidReceiveLocalNotificationResponseCallback?.call(response);
      },
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundLocalNotificationResponse,
    );
    _localNotificationsInitialized = true;
    debugPrint("✅ Serviço de Notificação Local Inicializado.");
  }

  void _onDidReceiveIOSLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    debugPrint(
      "iOS < 10 notificação LOCAL em primeiro plano: id: $id, title: $title, payload: $payload",
    );
    if (_onDidReceiveLocalNotificationResponseCallback != null &&
        payload != null) {
      _onDidReceiveLocalNotificationResponseCallback!(
        NotificationResponse(
          payload: payload,
          id: id,
          actionId: '',
          input: '',
          notificationResponseType:
              NotificationResponseType.selectedNotification,
        ),
      );
    }
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundLocalNotificationResponse(
    NotificationResponse response,
  ) {
    debugPrint(
      "onDidReceiveBackgroundNotificationResponse (local): payload: ${response.payload}",
    );
  }

  Future<void> _initializeFirebaseMessaging() async {
    debugPrint("Inicializando Firebase Messaging...");
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM: Permissão concedida pelo usuário.');

      debugPrint("FCM: Tentando obter o token FCM...");
      try {
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          debugPrint("✅ Firebase Messaging Token OBTIDO COM SUCESSO: $token");
          // >>> NOVA CHAMADA PARA SALVAR O TOKEN <<<
          await _saveTokenToFirestore(token);
          // >>> FIM DA NOVA CHAMADA <<<
        } else {
          debugPrint(
            "⚠️ FCM: getToken() retornou null. Nenhuma exceção, mas o token é nulo.",
          );
        }
      } catch (e, s) {
        debugPrint("❌ FCM: ERRO AO OBTER TOKEN: $e");
        debugPrint("   StackTrace do erro ao obter token: $s");
      }
    } else {
      debugPrint('FCM: Permissão NÃO concedida pelo usuário.');
      _fcmInitialized = false;
      debugPrint(
        "❌ Firebase Messaging NÃO pôde ser totalmente inicializado devido à falta de permissão.",
      );
      return;
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM: Mensagem recebida em PRIMEIRO PLANO!');
      debugPrint('Dados da mensagem FCM: ${message.data}');
      if (message.notification != null) {
        debugPrint(
          'Notificação da mensagem FCM: ${message.notification?.title} - ${message.notification?.body}',
        );
        showNotificationNow(
          id: message.hashCode,
          title: message.notification!.title ?? 'Nova Mensagem',
          body: message.notification!.body ?? '',
          payload:
              message.data['payload'] as String? ?? message.data.toString(),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM: Mensagem que ABRIU O APP:');
      debugPrint('Dados da mensagem FCM: ${message.data}');
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM: App aberto do estado TERMINADO por uma mensagem:');
      debugPrint('Dados da mensagem FCM: ${initialMessage.data}');
    }
    _fcmInitialized = true;
    debugPrint(
      "✅ Firebase Messaging Configurado (verifique acima se o token foi obtido e salvo).",
    );
  }

  // >>> NOVA FUNÇÃO PARA SALVAR O TOKEN NO FIRESTORE <<<
  Future<void> _saveTokenToFirestore(String token) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      debugPrint("Firestore Token Save: Usuário não logado. Token não salvo.");
      return;
    }

    String userId = currentUser.uid;
    debugPrint(
      "Firestore Token Save: Tentando salvar token para o usuário $userId",
    );

    try {
      final DocumentReference userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId); // Adapte 'users' se necessário

      final DocumentSnapshot userDocSnapshot = await userDocRef.get();

      if (userDocSnapshot.exists) {
        // Explicitamente converte para Map<String, dynamic> antes de acessar o campo
        Map<String, dynamic>? userData =
            userDocSnapshot.data() as Map<String, dynamic>?;
        String? existingToken = userData?['fcmToken'];

        if (existingToken == token) {
          debugPrint(
            "Firestore Token Save: Token já está atualizado no Firestore para o usuário $userId.",
          );
          return;
        }
      }

      await userDocRef.set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        "✅ Token FCM salvo/atualizado no Firestore para o usuário $userId",
      );
    } catch (e) {
      debugPrint(
        "❌ Erro ao salvar token FCM no Firestore para o usuário $userId: $e",
      );
    }
  }
  // >>> FIM DA NOVA FUNÇÃO <<<

  Future<bool> requestPermissions() async {
    debugPrint("Solicitando permissões para Notificações Locais...");
    bool? androidPermissionGranted;
    bool? iosPermissionGranted;

    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _localNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidImplementation != null) {
          androidPermissionGranted =
              await androidImplementation.requestNotificationsPermission();
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _localNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        if (iosImplementation != null) {
          iosPermissionGranted = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }
    }
    bool granted =
        (androidPermissionGranted ?? false) || (iosPermissionGranted ?? false);
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android &&
            androidPermissionGranted == null)) {
      granted = true;
    }
    debugPrint(
      "Permissão de notificação LOCAL concedida: $granted (Android: $androidPermissionGranted, iOS: $iosPermissionGranted)",
    );
    return granted;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    if (!_localNotificationsInitialized) {
      debugPrint(
        "ERRO (scheduleNotification): Serviço de notificação local não inicializado.",
      );
      return;
    }
    if (scheduledDateTime.isBefore(
      DateTime.now().add(const Duration(seconds: 2)),
    )) {
      debugPrint(
        ">>> ERRO AGENDAMENTO (Local): Horário ($scheduledDateTime) passado ou muito próximo. Ignorando.",
      );
      return;
    }
    try {
      final tz.TZDateTime tzScheduledDateTime = tz.TZDateTime.from(
        scheduledDateTime,
        tz.local,
      );
      await _localNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'lembrei_de_pagar_scheduled_channel',
            'Lembretes Agendados de Contas',
            channelDescription:
                'Notificações agendadas para lembretes de pagamento de contas.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      debugPrint(
        ">>> SUCESSO: Notificação LOCAL AGENDADA com ID $id para $tzScheduledDateTime",
      );
    } catch (e, s) {
      debugPrint(
        ">>> ERRO GRAVE ao agendar notificação LOCAL: $e\nStackTrace: $s",
      );
    }
  }

  Future<void> showNotificationNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_localNotificationsInitialized) {
      debugPrint(
        "ERRO (showNotificationNow): Serviço de notificação local não inicializado.",
      );
      return;
    }
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'lembrei_de_pagar_immediate_channel',
          'Notificações Imediatas',
          channelDescription: 'Notificações disparadas imediatamente.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
    debugPrint(">>> SUCESSO: Notificação IMEDIATA MOSTRADA com ID $id");
  }

  Future<void> cancelNotification(int id) async {
    if (!_localNotificationsInitialized) return;
    await _localNotificationsPlugin.cancel(id);
    debugPrint("Notificação LOCAL CANCELADA com ID $id");
  }

  Future<void> cancelAllNotifications() async {
    if (!_localNotificationsInitialized) return;
    await _localNotificationsPlugin.cancelAll();
    debugPrint("Todas as notificações LOCAIS canceladas");
  }
}

// Função helper para gerar IDs de notificação únicos
int generateUniqueNotificationId(
  String accountId, {
  String reminderTypeSuffix = "",
}) {
  final String combinedId = "$accountId$reminderTypeSuffix";
  return (combinedId.hashCode & 0x7FFFFFFF);
}
