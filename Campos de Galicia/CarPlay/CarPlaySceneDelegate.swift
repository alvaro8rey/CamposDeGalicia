import UIKit
import CarPlay
import MapKit
import Combine

/// Scene Delegate para manejar la sesión de CarPlay
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    var interfaceController: CPInterfaceController?
    var window: CPWindow?
    private var carPlayManager: CarPlayManager?

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        print("========================================")
        print("🚗🚗🚗 CARPLAY CONECTADO 🚗🚗🚗")
        print("InterfaceController: \(interfaceController)")
        print("Window: \(String(describing: templateApplicationScene.carWindow))")
        print("========================================")
        Logger.debug("🚗 CarPlay conectado - InterfaceController: \(interfaceController)")

        self.interfaceController = interfaceController
        self.window = templateApplicationScene.carWindow

        print("📱 Inicializando CarPlayManager...")
        // Inicializar el manager de CarPlay
        carPlayManager = CarPlayManager(interfaceController: interfaceController)

        print("🎨 Configurando interfaz de CarPlay...")
        // Configurar la interfaz inicial
        carPlayManager?.setupInterface()

        print("✅ CarPlay completamente inicializado")

        // Track evento de analytics
        AnalyticsManager.shared.trackCustom(name: "carplay_connected", category: .navigation)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnect interfaceController: CPInterfaceController) {
        print("========== CARPLAY DESCONECTADO ==========")
        Logger.debug("🚗 CarPlay desconectado")

        self.interfaceController = nil
        self.carPlayManager = nil

        // Track evento de analytics
        AnalyticsManager.shared.trackCustom(name: "carplay_disconnected", category: .navigation)
    }
}
