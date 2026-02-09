import SwiftUI
import UIKit

/// Helper para proporcionar feedback háptico consistente en toda la app
struct HapticFeedback {

    /// Feedback ligero para interacciones básicas
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Feedback medio para interacciones importantes
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Feedback pesado para acciones críticas
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Feedback suave para interacciones delicadas
    static func soft() {
        if #available(iOS 17.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        } else {
            light()
        }
    }

    /// Feedback rígido para confirmaciones fuertes
    static func rigid() {
        if #available(iOS 17.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        } else {
            medium()
        }
    }

    /// Feedback de éxito
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Feedback de advertencia
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Feedback de error
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Feedback de selección
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

/// ViewModifier para añadir feedback háptico a botones
struct HapticButtonModifier: ViewModifier {
    let style: HapticStyle
    let isEnabled: Bool

    enum HapticStyle {
        case light, medium, heavy, soft, rigid, selection
    }

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        guard isEnabled else { return }
                        switch style {
                        case .light:
                            HapticFeedback.light()
                        case .medium:
                            HapticFeedback.medium()
                        case .heavy:
                            HapticFeedback.heavy()
                        case .soft:
                            HapticFeedback.soft()
                        case .rigid:
                            HapticFeedback.rigid()
                        case .selection:
                            HapticFeedback.selection()
                        }
                    }
            )
    }
}

/// Extensión para facilitar el uso del modifier
extension View {
    func hapticFeedback(_ style: HapticButtonModifier.HapticStyle = .medium, isEnabled: Bool = true) -> some View {
        modifier(HapticButtonModifier(style: style, isEnabled: isEnabled))
    }
}
