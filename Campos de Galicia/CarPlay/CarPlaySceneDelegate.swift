import UIKit
import CarPlay
import MapKit
import Combine

/// Scene Delegate para manejar la sesión de CarPlay
@objc(CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    var interfaceController: CPInterfaceController?
    private var carPlayManager: CarPlayManager?

    // MARK: - CPTemplateApplicationSceneDelegate Methods

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        Logger.debug("🚗 CarPlay conectado")

        self.interfaceController = interfaceController

        Logger.debug("📱 Inicializando CarPlayManager...")
        carPlayManager = CarPlayManager(interfaceController: interfaceController)

        Logger.debug("🎨 Configurando interfaz de CarPlay...")
        carPlayManager?.setupInterface()

        Logger.debug("✅ CarPlay configurado completamente")

        AnalyticsManager.shared.trackCustom(name: "carplay_connected", category: .navigation)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnect interfaceController: CPInterfaceController) {
        Logger.debug("🚗 CarPlay desconectado")

        self.interfaceController = nil
        self.carPlayManager = nil

        AnalyticsManager.shared.trackCustom(name: "carplay_disconnected", category: .navigation)
    }
}
