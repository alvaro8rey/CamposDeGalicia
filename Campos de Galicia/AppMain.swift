import SwiftUI
import CoreLocation
import Supabase
import UserNotifications

extension Notification.Name {
    static let showResetPassword = Notification.Name("showResetPassword")
}

@main
struct AppMain: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

    // Navegación desde notificaciones (deep linking)
    @State private var notificationCampoID: UUID? = nil
    @State private var shouldShowLogros: Bool = false
    @State private var isProcessingDeepLink: Bool = false

    // Task de limpieza periódica
    @State private var cleanupTask: Task<Void, Never>?

    // Bandera para activar auto check-in solo una vez al inicio
    @State private var hasInitializedAutoCheckin: Bool = false

    init() {
        // --- CAMBIO: Configuración de Apariencia Nativa ---
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        // --------------------------------------------------

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
            if let err = err { Logger.debug("🔔 notif auth err: \(err.localizedDescription)") }
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            // --- CAMBIO: Envolvemos en ZStack para controlar el fondo ---
            ZStack {
                themeManager.currentTheme.colorScheme == .dark ? Color.black.ignoresSafeArea() : Color.white.ignoresSafeArea()
                
                TabView(selection: Binding(
                    get: { self.selectedTab },
                    set: { newTab in
                        if self.isMapNavigating && self.selectedTab == 1 && newTab != 1 {
                            self.pendingTab = newTab
                            self.showExitRouteAlert = true
                        } else {
                            self.selectedTab = newTab
                        }
                    }
                )) {
                    // TAB 0: INICIO
                    NavigationView {
                        ContentView(
                            distanciaPredeterminada: $distanciaPredeterminada,
                            notificationCampoID: $notificationCampoID
                        )
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
                        UserView(
                            distanciaPredeterminada: $distanciaPredeterminada,
                            shouldShowLogros: $shouldShowLogros
                        )
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
                // --- CAMBIO: El modificador clave ---
                .ignoresSafeArea(.all, edges: .bottom)
                // ------------------------------------
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

                cleanupTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                        guard !Task.isCancelled else { break }
                        await camposViewModel.cleanExpiredExtras()
                    }
                }
            }
            .onChange(of: camposViewModel.campos) { oldValue, newValue in
                if !hasInitializedAutoCheckin && !newValue.isEmpty && geofenceManager.autoCheckinEnabled {
                    Logger.debug("🚀 Campos cargados (\(newValue.count)) - activando auto check-in al arranque")
                    hasInitializedAutoCheckin = true
                    geofenceManager.setAutoCheckin(true, campos: newValue)
                } else if hasInitializedAutoCheckin && geofenceManager.autoCheckinEnabled {
                    geofenceManager.refreshWith(campos: newValue)
                }
            }
            .onDisappear {
                cleanupTask?.cancel()
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didTapNotification)) { notification in
                handleNotificationNavigation(notification: notification)
            }
            .alert(L(.navRouteInProgress), isPresented: $showExitRouteAlert) {
                Button(L(.navContinueRoute), role: .cancel) {
                    self.selectedTab = 1
                }
                Button(L(.navStopAndExit), role: .destructive) {
                    self.isMapNavigating = false
                    DispatchQueue.main.async {
                        self.selectedTab = pendingTab
                    }
                }
            } message: {
                Text(L(.navCancelMessage))
            }
            .alert(isPresented: $showVerificationAlert) {
                Alert(
                    title: Text(L(.navVerification)),
                    message: Text(verificationResult),
                    dismissButton: .default(Text(L(.navAccept)))
                )
            }
            .overlay(
                Group {
                    if isProcessingDeepLink {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                    }
                }
            )
        }
    }

    func handleDeepLink(url: URL) {
        guard url.scheme == "camposdegalicia" else { return }
    }

    func handleNotificationNavigation(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String else {
            return
        }

        isProcessingDeepLink = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch action {
            case "showCampoDetail":
                if let campoID = userInfo["campoID"] as? UUID {
                    self.selectedTab = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.notificationCampoID = campoID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isProcessingDeepLink = false
                        }
                    }
                }

            case "showLogros":
                self.selectedTab = 3
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.shouldShowLogros = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isProcessingDeepLink = false
                    }
                }

            default:
                self.isProcessingDeepLink = false
            }
        }
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
