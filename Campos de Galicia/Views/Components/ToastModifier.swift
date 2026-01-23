import SwiftUI

/// ViewModifier para mostrar toasts
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            VStack(spacing: 8) {
                ForEach(toastManager.toasts) { toast in
                    ToastView(toast: toast) {
                        toastManager.dismiss(toast)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

/// Extension para aplicar fácilmente el modifier
extension View {
    func withToast() -> some View {
        self.modifier(ToastModifier())
    }
}
