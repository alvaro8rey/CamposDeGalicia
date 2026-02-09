import Foundation
import Network
import SwiftUI

/// Monitor de conectividad de red
/// Monitorea el estado de la conexión a internet y notifica cambios
@MainActor
class NetworkMonitor: ObservableObject {

    // MARK: - Singleton
    static let shared = NetworkMonitor()

    // MARK: - Published Properties
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Connection Types
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown

        var description: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return L(.connectionTypeCellular)
            case .wired: return "Ethernet"
            case .unknown: return L(.connectionTypeUnknown)
            }
        }

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isMonitoring = false

    // MARK: - Initialization
    private init() {
        Logger.debug("NetworkMonitor inicializado")
    }

    // MARK: - Public Methods

    /// Inicia el monitoreo de red
    func startMonitoring() {
        guard !isMonitoring else {
            Logger.debug("NetworkMonitor ya está monitoreando")
            return
        }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.connectionType = self.determineConnectionType(from: path)

                // Log cambios
                if wasConnected != self.isConnected {
                    if self.isConnected {
                        Logger.success("✅ Conexión a internet restaurada (\(self.connectionType.description))")
                        self.postNotification(.networkConnected)
                    } else {
                        Logger.warning("⚠️ Conexión a internet perdida")
                        self.postNotification(.networkDisconnected)
                    }
                }
            }
        }

        monitor.start(queue: queue)
        isMonitoring = true
        Logger.info("NetworkMonitor iniciado")
    }

    /// Detiene el monitoreo de red
    func stopMonitoring() {
        guard isMonitoring else { return }

        monitor.cancel()
        isMonitoring = false
        Logger.info("NetworkMonitor detenido")
    }

    // MARK: - Private Methods

    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        }
        return .unknown
    }

    private func postNotification(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    // MARK: - Computed Properties

    /// Indica si hay conexión costosa (datos móviles)
    var isExpensive: Bool {
        connectionType == .cellular
    }

    /// Indica si la conexión es rápida (wifi/ethernet)
    var isFastConnection: Bool {
        connectionType == .wifi || connectionType == .wired
    }

    /// Mensaje de estado para mostrar al usuario
    var statusMessage: String {
        if isConnected {
            return "Conectado a \(connectionType.description)"
        } else {
            return L(.connectionOffline)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnected = Notification.Name("networkConnected")
    static let networkDisconnected = Notification.Name("networkDisconnected")
}

// MARK: - SwiftUI View Extension

extension View {
    /// Agrega un banner de estado de red a la vista
    func networkStatusBanner() -> some View {
        self.modifier(NetworkStatusBannerModifier())
    }
}

/// Modifier que muestra un banner cuando no hay conexión
struct NetworkStatusBannerModifier: ViewModifier {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    Text(L(.connectionOffline))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .transition(.move(edge: .top))
            }

            content
        }
    }
}
