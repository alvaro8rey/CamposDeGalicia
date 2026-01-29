import SwiftUI
import CoreLocation
import Supabase
import UserNotifications

extension Notification.Name {
    static let showResetPassword = Notification.Name("showResetPassword")
}

@main
struct AppMain: App {
    @StateObject private var camposViewModel: CamposViewModel
    @StateObject private var authViewModel = AuthViewModel.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var geofenceManager = GeofenceManager()
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var distanciaPredeterminada: Double = 10.0
    @State private var showVerificationAlert: Bool = false
    @State private var verificationResult: String = ""
    
    // Gestión de navegación y pestañas
    @State private var selectedTab: Int = 0
    @State private var isMapNavigating: Bool = false
    @State private var showExitRouteAlert: Bool = false
    @State private var pendingTab: Int = 0

    // Task de limpieza periódica
    @State private var cleanupTask: Task<Void, Never>?

    init() {
        let viewModel = CamposViewModel()
        _camposViewModel = StateObject(wrappedValue: viewModel)

        // Reducir cache para evitar problemas de memoria
        let imageCache = URLCache(
            memoryCapacity: 15_000_000,  // 15 MB (antes 50 MB)
            diskCapacity: 40_000_000      // 40 MB (antes 100 MB)
        )
        URLCache.shared = imageCache

        Task { @MainActor in
            NetworkMonitor.shared.startMonitoring()
        }

        Task {
            await viewModel.loadCampos()
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, err in
            if let err = err { print("🔔 notif auth err: \(err.localizedDescription)") }
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: Binding(
                get: { self.selectedTab },
                set: { newTab in
                    // Si intentamos salir de Mapa (1) mientras hay navegación activa
                    if self.isMapNavigating && self.selectedTab == 1 && newTab != 1 {
                        self.pendingTab = newTab
                        // Mostramos la alerta sin cambiar selectedTab para intentar bloquear el amago
                        self.showExitRouteAlert = true
                    } else {
                        self.selectedTab = newTab
                    }
                }
            )) {
                // TAB 0: INICIO
                NavigationView {
                    ContentView(distanciaPredeterminada: $distanciaPredeterminada)
                        .environmentObject(camposViewModel)
                        .environmentObject(authViewModel)
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(L(.tabHome))
                }
                .tag(0)

                // TAB 1: MAPA
                NavigationView {
                    // Pasamos isMapNavigating como Binding.
                    // Cuando lo pongamos en false desde aquí, MapaView debe reaccionar.
                    MapaView(externalIsNavigating: $isMapNavigating)
                        .environmentObject(camposViewModel)
                        .environmentObject(authViewModel)
                }
                .tabItem {
                    Image(systemName: "map.fill")
                    Text(L(.tabMap))
                }
                .tag(1)

                // TAB 2: CERCANOS
                NavigationView {
                    CamposCercanosView(
                        userLocation: $locationManager.userLocation,
                        isLoadingLocation: $locationManager.isLoading,
                        distanciaPredeterminada: $distanciaPredeterminada,
                        requestLocation: {
                            locationManager.requestLocation()
                        }
                    )
                    .environmentObject(camposViewModel)
                    .environmentObject(authViewModel)
                }
                .tabItem {
                    Image(systemName: "mappin.and.ellipse")
                    Text(L(.tabNearby))
                }
                .tag(2)

                // TAB 3: USUARIO
                NavigationView {
                    UserView(distanciaPredeterminada: $distanciaPredeterminada)
                        .environmentObject(camposViewModel)
                        .environmentObject(authViewModel)
                }
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text(L(.tabProfile))
                }
                .tag(3)
            }
            .id(themeManager.currentTheme.rawValue)
            .accentColor(.blue)
            .environmentObject(geofenceManager)
            .environmentObject(camposViewModel)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
            .withToast()
            .onAppear {
                locationManager.requestLocation()
                if geofenceManager.autoCheckinEnabled {
                    geofenceManager.refreshWith(campos: camposViewModel.campos)
                }

                // Limpiar cache expirado periódicamente para liberar memoria (cada 5 minutos)
                cleanupTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutos
                        guard !Task.isCancelled else { break }
                        await camposViewModel.cleanExpiredExtras()
                    }
                }
            }
            .onDisappear {
                // Cancelar la tarea de limpieza cuando la app se cierra
                cleanupTask?.cancel()
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
            // Alerta de seguridad para rutas activas
            .alert(L(.navRouteInProgress), isPresented: $showExitRouteAlert) {
                Button(L(.navContinueRoute), role: .cancel) {
                    // Forzamos la pestaña 1 por si hubo amago visual
                    self.selectedTab = 1
                }
                Button(L(.navStopAndExit), role: .destructive) {
                    // 1. IMPORTANTE: Cambiamos el estado de navegación a FALSE.
                    // Esto notificará a MapaView para que limpie la ruta y overlays.
                    self.isMapNavigating = false

                    // 2. Ejecutamos el cambio de pestaña después de limpiar
                    DispatchQueue.main.async {
                        self.selectedTab = pendingTab
                    }
                }
            } message: {
                Text(L(.navCancelMessage))
            }
            // Alerta de verificación de cuenta
            .alert(isPresented: $showVerificationAlert) {
                Alert(
                    title: Text(L(.navVerification)),
                    message: Text(verificationResult),
                    dismissButton: .default(Text(L(.navAccept)))
                )
            }
        }
    }

    func handleDeepLink(url: URL) {
        guard url.scheme == "camposdegalicia" else { return }
        // ... (Lógica de autenticación mantenida)
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoading: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
            isLoading = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            userLocation = location.coordinate
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
