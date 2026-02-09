import Foundation
import SwiftUI

/// Manager singleton para gestionar toasts en toda la app
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var toasts: [Toast] = []

    private let maxToasts = 3 // Máximo número de toasts visibles simultáneamente
    private var toastWindow: ToastWindow?

    private init() {
        // Crear la ventana de toasts para que aparezcan sobre todo
        setupToastWindow()
    }

    private func setupToastWindow() {
        // Esperar a que la escena de ventana esté disponible
        DispatchQueue.main.async { [weak self] in
            self?.toastWindow = ToastWindow()
        }
    }

    /// Muestra un toast de éxito
    func success(_ message: String, duration: Double = 3.0) {
        show(Toast(type: .success, message: message, duration: duration))
    }

    /// Muestra un toast de error
    func error(_ message: String, duration: Double = 4.0) {
        show(Toast(type: .error, message: message, duration: duration))
    }

    /// Muestra un toast de advertencia
    func warning(_ message: String, duration: Double = 3.5) {
        show(Toast(type: .warning, message: message, duration: duration))
    }

    /// Muestra un toast de información
    func info(_ message: String, duration: Double = 3.0) {
        show(Toast(type: .info, message: message, duration: duration))
    }

    /// Muestra un toast de logro desbloqueado
    func achievement(_ message: String, duration: Double = 4.0) {
        show(Toast(type: .achievement, message: message, duration: duration))
    }

    /// Muestra un toast de XP ganado
    func xpGained(_ amount: Int, reason: String, duration: Double = 3.0) {
        let message = LocalizationManager.shared.localized(.toastXPGained, amount, reason)
        show(Toast(type: .xp, message: message, duration: duration))
    }

    /// Muestra un toast de subida de nivel
    func levelUp(_ level: Int, duration: Double = 4.0) {
        let message = LocalizationManager.shared.localized(.toastLevelUp, level)
        show(Toast(type: .levelUp, message: message, duration: duration))
    }

    /// Muestra un toast personalizado
    func show(_ toast: Toast) {
        // Si ya hay el máximo de toasts, eliminar el más antiguo
        if toasts.count >= maxToasts {
            toasts.removeFirst()
        }
        toasts.append(toast)
    }

    /// Elimina un toast específico
    func dismiss(_ toast: Toast) {
        toasts.removeAll { $0.id == toast.id }
    }

    /// Elimina todos los toasts
    func dismissAll() {
        toasts.removeAll()
    }
}
