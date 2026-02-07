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
        print("")
        print("========================================")
        print("========================================")
        print("🚗🚗🚗 CARPLAY CONECTADO! 🚗🚗🚗")
        print("========================================")
        print("========================================")
        print("")
        Logger.debug("🚗 CarPlay conectado")

        self.interfaceController = interfaceController
        self.window = templateApplicationScene.carWindow

        print("✅ Interface controller asignado")
        print("✅ Window asignada")

        // Inicializar el manager de CarPlay
        print("📱 Inicializando CarPlayManager...")
        carPlayManager = CarPlayManager(interfaceController: interfaceController)

        // Configurar la interfaz inicial
        print("🎨 Configurando interfaz de CarPlay...")
        carPlayManager?.setupInterface()

        print("========================================")
        print("✅ CARPLAY CONFIGURADO COMPLETAMENTE")
        print("========================================")

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
