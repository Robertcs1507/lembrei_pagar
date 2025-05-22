import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lembrei_pegar/services/notification_service.dart'; // Importe seu NotificationService
import 'package:intl/intl.dart'; // Para formatar datas

// Variável global para a porta de comunicação com a UI (se necessário)
// SendPort? uiSendPort;

// A função de callback PRECISA ser uma função de nível superior ou um método estático.
@pragma('vm:entry-point') // Necessário para AOT no release mode
void alarmCallback() async {
  print("ALARM DISPARADO! - ${DateTime.now()}");

  final NotificationService notificationService = NotificationService();

  int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
  String accountName = "Conta de Teste (Alarme)";
  DateTime dueDate = DateTime.now(); // A notificação é para AGORA

  print("Callback do alarme: Mostrando notificação...");

  await notificationService.scheduleNotification(
    // Usando scheduleNotification para reusar a lógica de details
    id: notificationId,
    title: "Alarme Lembrei de Pagar!",
    body: "Sua conta '$accountName' venceu! (Alarme)",
    scheduledDateTime: DateTime.now().add(
      Duration(seconds: 1),
    ), // Dispara quase imediatamente
    payload: "alarm_payload_$notificationId",
  );

  print("Callback do alarme: Notificação (tentativa) enviada.");
}
