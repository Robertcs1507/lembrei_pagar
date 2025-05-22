import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() => _notificationService;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initializeNotifications(
    Function(NotificationResponse)? onDidReceiveNotificationResponse,
  ) async {
    if (_isInitialized) {
      print("Serviço de Notificação já inicializado.");
      return;
    }

    tz.initializeTimeZones();
    // Para flutter_local_notifications v17+, confiaremos no tz.local dentro de zonedSchedule
    // para usar o fuso horário do dispositivo.
    // Se for absolutamente necessário definir um fuso padrão aqui para outros cálculos com tz.local:
    try {
      // Tenta definir um fuso padrão se necessário, mas tz.local no agendamento é o principal.
      // tz.setLocalLocation(tz.getLocation('America/Sao_Paulo')); // Exemplo de fallback
      print(
        "Timezones inicializados. tz.local será usado para agendamento no zonedSchedule.",
      );
    } catch (e) {
      print(
        "Erro na inicialização de timezones (ou ao tentar definir um local padrão): $e.",
      );
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          onDidReceiveLocalNotification: (
            int id,
            String? title,
            String? body,
            String? payload,
          ) async {
            debugPrint(
              "iOS < 10 notificação em primeiro plano: id: $id, title: $title",
            );
          },
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
    _isInitialized = true;
    print("Serviço de Notificação Inicializado com SUCESSO.");
  }

  Future<bool> requestPermissions() async {
    bool? androidPermissionGranted;
    bool? iosPermissionGranted;

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidImplementation != null) {
      androidPermissionGranted =
          await androidImplementation.requestNotificationsPermission();
      print(
        "Permissão de notificação Android concedida: $androidPermissionGranted",
      );
    }

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (iosImplementation != null) {
      iosPermissionGranted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print("Permissão de notificação iOS concedida: $iosPermissionGranted");
    }
    return (androidPermissionGranted ?? false) ||
        (iosPermissionGranted ?? false);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print("ERRO: Serviço de notificação não inicializado.");
      return;
    }
    print(
      "---- Tentando agendar notificação LOCAL ---- ID: $id, Título: $title, Agendado: $scheduledDateTime",
    );

    if (scheduledDateTime.isBefore(
      DateTime.now().add(const Duration(seconds: 10)),
    )) {
      print(
        ">>> ERRO AGENDAMENTO (Local): Horário ($scheduledDateTime) passado ou muito próximo. Ignorando.",
      );
      return;
    }

    try {
      final tz.TZDateTime tzScheduledDateTime = tz.TZDateTime.from(
        scheduledDateTime,
        tz.local,
      );
      print(
        "Horário Agendado LOCAL Convertido para TZDateTime (${tz.local.name}): $tzScheduledDateTime",
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lembrei_de_pagar_channel_id_01',
            'Lembretes de Contas',
            channelDescription:
                'Notificações para lembretes de pagamento de contas.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            ticker: 'ticker',
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
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
      print(
        ">>> SUCESSO: Notificação LOCAL AGENDADA com ID $id para $scheduledDateTime (TZ: $tzScheduledDateTime)",
      );
    } catch (e, s) {
      print(">>> ERRO GRAVE ao agendar notificação LOCAL: $e\nStackTrace: $s");
    }
  }

  Future<void> showNotificationNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print(
        "ERRO (showNotificationNow): Serviço de notificação não inicializado.",
      );
      return;
    }
    print(
      "---- Mostrando notificação IMEDIATAMENTE (showNotificationNow) ---- ID: $id",
    );
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'lembrei_de_pagar_alarm_channel',
          'Lembretes de Alarme',
          channelDescription: 'Notificações disparadas por alarmes agendados.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          ticker: 'ticker',
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
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
    print(">>> SUCESSO: Notificação IMEDIATA MOSTRADA com ID $id");
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    print("Notificação CANCELADA com ID $id");
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print("Todas as notificações canceladas");
  }
}

int generateUniqueNotificationId(
  String accountId, {
  String reminderTypeSuffix = "",
}) {
  final String combinedId = "$accountId$reminderTypeSuffix";
  return combinedId.hashCode.abs() % 2147483647;
}
