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

    // ✅ NUEVO: Campo preseleccionado para abrir en mapa
    @State private var mapSelectedCampoId: UUID? = nil

    // Task de limpieza periódica
    @State private var cleanupTask: Task<Void, Never>?

    // Bandera para activar auto check-in solo una vez al inicio
    @State private var hasInitializedAutoCheckin: Bool = false

    // Password reset deep link
    @State private var showPasswordReset: Bool = false


    // Computed property para el binding del TabView
    private var tabSelection: Binding<Int> {
        Binding(
            get: { self.selectedTab },
            set: { newTab in
                self.handleTabChange(to: newTab)
            }
        )
    }

    // Computed property para el color de fondo
    private var backgroundColor: some View {
        Group {
            if themeManager.currentTheme.colorScheme == .dark {
                Color.black.ignoresSafeArea()
            } else {
                Color.white.ignoresSafeArea()
            }
        }
    }

    // MARK: - Tab Views

    private var homeTab: some View {
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
    }

    private var mapTab: some View {
        NavigationView {
            MapaView(externalIsNavigating: $isMapNavigating, preselectedCampoId: mapSelectedCampoId)
                .environmentObject(camposViewModel)
                .environmentObject(authViewModel)
        }
        .tabItem {
            Image(systemName: "map.fill")
            Text(L(.tabMap))
        }
        .tag(1)
    }

    private var nearbyTab: some View {
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
    }

    private var profileTab: some View {
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

    // MARK: - Alert Buttons

    private var continueRouteButton: some View {
        Button(L(.navContinueRoute), role: .cancel) {
            self.selectedTab = 1
        }
    }

    private var stopRouteButton: some View {
        Button(L(.navStopAndExit), role: .destructive) {
            self.isMapNavigating = false
            DispatchQueue.main.async {
                self.selectedTab = pendingTab
            }
        }
    }

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
                backgroundColor

                TabView(selection: tabSelection) {
                    homeTab
                    mapTab
                    nearbyTab
                    profileTab
                }
                // --- CAMBIO: El modificador clave ---
                .ignoresSafeArea(.all, edges: .bottom)
                // ------------------------------------
            }
            .accentColor(.blue)
            .environmentObject(geofenceManager)
            .environmentObject(camposViewModel)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
            .withToast()
            .onAppear {
                locationManager.requestLocation()

                // 📊 Analytics: Track app launch
                AnalyticsManager.shared.track(.appLaunched)

                // Configurar propiedades de usuario
                if let userId = authViewModel.user?.id {
                    AnalyticsManager.shared.setUserProperties([
                        "user_id": userId.uuidString
                    ])
                }

                cleanupTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                        guard !Task.isCancelled else { break }
                        await camposViewModel.cleanExpiredExtras()
                    }
                }

                // Recovery fallback: si el flag está activo y el SDK procesó la URL, mostrar formulario
                if authViewModel.isRecoveryInProgress {
                    print("🔑 [Recovery] Flag pendiente detectado en onAppear")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if !self.showPasswordReset && authViewModel.isRecoveryInProgress && supabase.auth.currentUser != nil {
                            print("🔑 [Recovery] Sesión detectada, mostrando formulario (fallback onAppear)")
                            self.showPasswordReset = true
                        }
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowCampoInMap"))) { notification in
                // ✅ NUEVO: Abrir campo en el mapa
                if let campoIdString = notification.userInfo?["campoId"] as? String,
                   let campoId = UUID(uuidString: campoIdString) {
                    mapSelectedCampoId = campoId
                    selectedTab = 1 // Cambiar a tab de mapa
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Recovery fallback: cuando la app vuelve de background con el flag activo
                if authViewModel.isRecoveryInProgress && !showPasswordReset {
                    print("🔑 [Recovery] App activa con flag de recovery pendiente")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if !self.showPasswordReset && authViewModel.isRecoveryInProgress && supabase.auth.currentUser != nil {
                            print("🔑 [Recovery] Sesión detectada en didBecomeActive, mostrando formulario")
                            self.showPasswordReset = true
                        }
                    }
                }
            }
            .alert(L(.navRouteInProgress), isPresented: $showExitRouteAlert, actions: {
                continueRouteButton
                stopRouteButton
            }, message: {
                Text(L(.navCancelMessage))
            })
            .alert(isPresented: $showVerificationAlert) {
                Alert(
                    title: Text(L(.navVerification)),
                    message: Text(verificationResult),
                    dismissButton: .default(Text(L(.navAccept)))
                )
            }
            .sheet(isPresented: $showPasswordReset, onDismiss: {
                // Limpiar URL y flags de recovery al cerrar (cancelar o tras éxito)
                UserDefaults.standard.removeObject(forKey: "recovery_url")
                if authViewModel.isRecoveryInProgress {
                    authViewModel.isRecoveryInProgress = false
                    Task {
                        try? await supabase.auth.signOut()
                        authViewModel.isAuthenticated = false
                        authViewModel.user = nil
                    }
                }
            }) {
                PasswordResetCompletionView()
                    .environmentObject(LocalizationManager.shared)
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

    // MARK: - Tab Navigation

    private func handleTabChange(to newTab: Int) {
        if self.isMapNavigating && self.selectedTab == 1 && newTab != 1 {
            self.pendingTab = newTab
            self.showExitRouteAlert = true
        } else {
            self.selectedTab = newTab

            // 📊 Analytics: Track tab change
            let tabNames = ["home", "map", "nearby", "profile"]
            if newTab < tabNames.count {
                AnalyticsManager.shared.trackTabChange(to: tabNames[newTab])
            }
        }
    }

    func handleDeepLink(url: URL) {
        print("🔗 [DeepLink] URL recibida: \(url.absoluteString)")
        let host = url.host ?? ""

        // --- Flujo de restablecimiento de contraseña ---
        // Detectado por host explícito; no depende del flag isRecoveryInProgress.
        if host == "reset-callback" {
            print("🔑 [DeepLink] Enlace de reset recibido")
            authViewModel.isRecoveryInProgress = true // por si acaso no estaba activo
            UserDefaults.standard.set(url.absoluteString, forKey: "recovery_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showPasswordReset = true
            }
            return
        }

        // --- Flujo de verificación de email ---
        if host == "verify-callback" {
            print("✉️ [DeepLink] Enlace de verificación recibido")
            Task {
                do {
                    let session = try await supabase.auth.session(from: url)
                    print("✅ [DeepLink/Verify] Email verificado: \(session.user.email ?? "unknown")")
                    authViewModel.user = session.user
                    authViewModel.isAuthenticated = true
                    authViewModel.nombre = session.user.userMetadata["nombre"] as? String ?? ""
                    authViewModel.apellidos = session.user.userMetadata["apellidos"] as? String ?? ""
                    try? await authViewModel.loadProfileData()
                    await ProgressStore.shared.loadInitialData(for: session.user.id.uuidString)
                    ToastManager.shared.success(L(.navVerificationSuccess))
                } catch {
                    print("❌ [DeepLink/Verify] Error: \(error.localizedDescription)")
                    ToastManager.shared.error(L(.navVerificationError))
                }
            }
            return
        }

        // --- Otros deep links (legacy / fallback) ---
        Task {
            do {
                let session = try await supabase.auth.session(from: url)
                print("✅ [DeepLink] Sesión establecida: \(session.user.email ?? "unknown")")
                authViewModel.user = session.user
                authViewModel.isAuthenticated = true
            } catch {
                print("❌ [DeepLink] Error: \(error.localizedDescription)")
            }
        }
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
