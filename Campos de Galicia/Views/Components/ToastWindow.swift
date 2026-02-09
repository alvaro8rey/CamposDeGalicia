import SwiftUI
import UIKit

/// Vista que se renderiza en una UIWindow separada para aparecer sobre todos los modales
@MainActor
class ToastWindow: UIWindow {
    private var hostingController: UIHostingController<ToastWindowContentView>?

    init() {
        // Crear la ventana en el nivel más alto posible
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            super.init(windowScene: windowScene)
        } else {
            super.init(frame: UIScreen.main.bounds)
        }

        // Configurar la ventana
        self.windowLevel = .alert + 1 // Por encima de alerts y sheets
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true

        // Crear el hosting controller con la vista de toasts
        let contentView = ToastWindowContentView()
        hostingController = UIHostingController(rootView: contentView)
        hostingController?.view.backgroundColor = .clear

        self.rootViewController = hostingController
        self.isHidden = false
    }

    /// Requerido por UIWindow pero no soportado
    /// Esta ventana solo debe crearse programáticamente, nunca desde Storyboards o XIBs
    /// Si este método es llamado, indica un error de implementación en el código
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - ToastWindow must be initialized programmatically")
    }

    /// Permite que los toques pasen a través cuando no hay toasts
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        // Si el toque es en el rootViewController y no en un toast, devolver nil para que pase a través
        if hitView == self.rootViewController?.view || hitView == self {
            return nil
        }

        return hitView
    }
}

/// Vista de contenido que muestra los toasts
struct ToastWindowContentView: View {
    @ObservedObject var toastManager = ToastManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(toastManager.toasts) { toast in
                ToastView(toast: toast) {
                    toastManager.dismiss(toast)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
