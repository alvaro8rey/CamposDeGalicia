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
        Logger.debug("🚗 CarPlay conectado")

        self.interfaceController = interfaceController
        self.window = templateApplicationScene.carWindow

        // Inicializar el manager de CarPlay
        carPlayManager = CarPlayManager(interfaceController: interfaceController)

        // Configurar la interfaz inicial
        carPlayManager?.setupInterface()

        // Track evento de analytics
        AnalyticsManager.shared.trackCustom(name: "carplay_connected", category: .navigation)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnect interfaceController: CPInterfaceController) {
        Logger.debug("🚗 CarPlay desconectado")

        self.interfaceController = nil
        self.carPlayManager = nil

        // Track evento de analytics
        AnalyticsManager.shared.trackCustom(name: "carplay_disconnected", category: .navigation)
    }
}
