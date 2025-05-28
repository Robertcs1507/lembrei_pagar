import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lembrei_pegar/services/notification_service.dart';
import 'package:intl/intl.dart'; // Usado no params do alarme

@pragma('vm:entry-point')
Future<void> alarmCallback(int alarmId, Map<String, dynamic> params) async {
  print("----------------------------------------------------");
  print("ALARM CALLBACK DISPARADO! (android_alarm_manager_plus)");
  print("ID do Alarme Recebido: $alarmId");
  print("Horário do Disparo (UTC): ${DateTime.now().toUtc()}");
  print("Parâmetros Recebidos: $params");
  print("----------------------------------------------------");

  final NotificationService notificationService = NotificationService();

  final String accountName =
      params['accountName'] as String? ?? "Lembrete de Conta";
  final String accountIdFromPayload =
      params['accountId'] as String? ?? "alarm_payload_$alarmId";
  final String notificationTitle =
      params['title'] as String? ?? "Lembrete Importante!";
  final String notificationBody =
      params['body'] as String? ?? "Sua conta '$accountName' requer atenção.";
  final int localNotificationIdToShow =
      params['notificationId'] as int? ?? alarmId;

  print(
    "Callback do alarme: Preparando para mostrar notificação local com ID $localNotificationIdToShow para '$accountName'",
  );

  try {
    // A inicialização do NotificationService deve ter ocorrido no main.dart
    await notificationService.showNotificationNow(
      id: localNotificationIdToShow,
      title: notificationTitle,
      body: notificationBody,
      payload: accountIdFromPayload,
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
