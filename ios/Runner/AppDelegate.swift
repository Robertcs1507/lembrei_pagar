import Flutter
import UIKit
import flutter_local_notifications // <<< ADICIONE ESTA LINHA

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // <<< ADICIONE ESTA SEÇÃO PARA NOTIFICAÇÕES LOCAIS NO iOS >>>
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Para registrar plugins que podem ser necessários para callbacks em background (como notificações)
    // Se você já tem essa linha de outra configuração do Firebase, não precisa duplicar.
    // Mas é importante para o flutter_local_notifications poder chamar código Dart em alguns cenários.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }
    // <<< FIM DA SEÇÃO DE NOTIFICAÇÕES LOCAIS >>>

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Opcional: Se você precisar lidar com ações de notificação mais complexas
  // ou se a linha acima para UNUserNotificationCenter.current().delegate não for suficiente
  // para todas as versões do iOS que você suporta, você pode precisar adicionar mais métodos de delegate aqui.
  // No entanto, para a maioria dos casos de notificações locais, a configuração acima
  // e a solicitação de permissão via DarwinInitializationSettings no Dart devem ser suficientes.
}