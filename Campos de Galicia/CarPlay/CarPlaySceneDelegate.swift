import UIKit
import CarPlay
import MapKit
import Combine

/// Scene Delegate para manejar la sesión de CarPlay
/// IMPORTANTE: Solo implementa CPTemplateApplicationSceneDelegate, NO UISceneDelegate
@objc(CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    var interfaceController: CPInterfaceController?
    var window: CPWindow?
    private var carPlayManager: CarPlayManager?

    // MARK: - CPTemplateApplicationSceneDelegate Methods

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
        print("✅ Window asignada: \(String(describing: self.window))")

        // Inicializar el manager de CarPlay
        // IMPORTANTE: NO creamos el MKMapView manualmente.
        // El sistema lo crea automáticamente cuando asignamos el CPMapTemplate.
        print("📱 Inicializando CarPlayManager...")
        carPlayManager = CarPlayManager(interfaceController: interfaceController, window: self.window)

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
