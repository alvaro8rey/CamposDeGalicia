import UserNotifications
import Foundation

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.debug("🔔 Notificación recibida en primer plano: \(notification.request.identifier)")
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.debug("👉 Usuario interactuó con notificación: \(response.notification.request.identifier)")

        // Obtener datos de la notificación
        let userInfo = response.notification.request.content.userInfo

        // Procesar según el tipo de notificación
        if let type = userInfo["type"] as? String {
            Logger.debug("📱 Tipo de notificación: \(type)")

            switch type {
            case "autoCheckin":
                // Notificación de campo visitado - navegar a detalle del campo
                if let campoIDString = userInfo["campoID"] as? String,
                   let campoID = UUID(uuidString: campoIDString) {
                    Logger.debug("🎯 Navegando a detalle del campo: \(campoID)")
                    NotificationCenter.default.post(
                        name: .didTapNotification,
                        object: nil,
                        userInfo: ["action": "showCampoDetail", "campoID": campoID]
                    )
                }

            case "dailyReward":
                // Notificación de recompensa diaria - navegar a pantalla de logros
                Logger.debug("🏆 Navegando a pantalla de logros")
                NotificationCenter.default.post(
                    name: .didTapNotification,
                    object: nil,
                    userInfo: ["action": "showLogros"]
                )

            default:
                Logger.debug("⚠️ Tipo de notificación desconocido: \(type)")
            }
        } else {
            Logger.debug("ℹ️ Notificación sin tipo específico")
        }

        completionHandler()
    }
}
