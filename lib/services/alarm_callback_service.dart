import 'dart:ui'; // Para IsolateNameServer (se for usar comunicação de isolate) e @pragma
import 'package:flutter/material.dart'; // Para debugPrint
import 'package:lembrei_pegar/services/notification_service.dart'; // Importe seu NotificationService
// Se você precisar do modelo Account aqui para reconstruir o objeto, importe-o.
// import 'package:lembrei_pegar/models/account.dart';
import 'package:intl/intl.dart'; // Se for usar para formatar datas dentro do callback

// A função de callback PRECISA ser uma função de nível superior ou um método estático.
@pragma(
  'vm:entry-point',
) // Garante que o compilador AOT não remova esta função.
Future<void> alarmCallback(int alarmId, Map<String, dynamic> params) async {
  // <<< ASSINATURA CORRIGIDA
  print("----------------------------------------------------");
  print("ALARM CALLBACK DISPARADO! (android_alarm_manager_plus)");
  print("ID do Alarme Recebido: $alarmId");
  print("Horário do Disparo (UTC): ${DateTime.now().toUtc()}");
  print("Parâmetros Recebidos: $params");
  print("----------------------------------------------------");

  // É crucial que o NotificationService já tenha sido inicializado na thread principal do app.
  // Tentar inicializar plugins que dependem de UI (como flutter_local_notifications)
  // diretamente em um isolate de background é complexo e pode falhar.
  final NotificationService notificationService = NotificationService();

  // Extrair dados dos parâmetros que passamos ao agendar o alarme
  final String accountName =
      params['accountName'] as String? ?? "Lembrete de Conta";
  final String accountIdFromPayload =
      params['accountId'] as String? ?? "payload_alarme_$alarmId";
  final String notificationTitle =
      params['title'] as String? ?? "Lembrete Importante!";
  final String notificationBody =
      params['body'] as String? ?? "Sua conta '$accountName' requer atenção.";

  // Usa o ID da notificação local que passamos nos params,
  // ou o ID do alarme como um fallback (mas o ideal é usar o que foi passado).
  final int localNotificationIdToShow =
      params['notificationId'] as int? ?? alarmId;

  print(
    "Callback do alarme: Preparando para mostrar notificação local com ID $localNotificationIdToShow para '$accountName'",
  );

  try {
    // Usa o método showNotificationNow do NotificationService para exibir a notificação imediatamente.
    // Este método deve usar uma instância já inicializada do flutterLocalNotificationsPlugin.
    await notificationService.showNotificationNow(
      id: localNotificationIdToShow,
      title: notificationTitle,
      body: notificationBody,
      payload: accountIdFromPayload, // Este será o payload da notificação local
    );
    print(
      "✅ Callback do alarme: showNotificationNow para '$accountName' foi chamado com sucesso.",
    );
  } catch (e, s) {
    print(
      "❌ Erro CRÍTICO no alarmCallback ao tentar mostrar notificação via showNotificationNow: $e",
    );
    print("StackTrace: $s");
  }
}
