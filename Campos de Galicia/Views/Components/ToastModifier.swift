import SwiftUI

/// ViewModifier para mostrar toasts
/// NOTA: Los toasts ahora se muestran en una UIWindow separada (ToastWindow)
/// Este modifier se mantiene por compatibilidad pero ya no renderiza nada
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        // Los toasts se renderizan en ToastWindow, no aquí
        content
    }
}

/// Extension para aplicar fácilmente el modifier
extension View {
    func withToast() -> some View {
        self.modifier(ToastModifier())
    }
}
