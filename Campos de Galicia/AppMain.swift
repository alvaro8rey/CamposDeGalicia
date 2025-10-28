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
    @StateObject private var locationManager = LocationManager()
    @StateObject private var geofenceManager = GeofenceManager()   // ✅ nuevo
    @State private var distanciaPredeterminada: Double = 10.0

    @State private var showVerificationAlert: Bool = false
    @State private var verificationResult: String = ""

    init() {
        let viewModel = CamposViewModel()
        _camposViewModel = StateObject(wrappedValue: viewModel)
        Task {
            await viewModel.loadCampos()
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, err in
            if let err = err { print("🔔 notif auth err: \(err.localizedDescription)") }
            print("🔔 notif auth granted: \(ok)")
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView {
                    ContentView(
                        distanciaPredeterminada: $distanciaPredeterminada
                    )
                    .environmentObject(camposViewModel)
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Inicio")
                }
                .tag(0)

                NavigationView {
                    MapaView()
                        .environmentObject(camposViewModel)
                }
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Mapa")
                }
                .tag(1)

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
                }
                .tabItem {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Cercanos")
                }
                .tag(2)

                NavigationView {
                    UserView(
                        distanciaPredeterminada: $distanciaPredeterminada
                    )
                    .environmentObject(camposViewModel)
                }
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Usuario")
                }
                .tag(3)
            }
            .accentColor(.blue)
            .environmentObject(geofenceManager) // ✅ inyectamos el manager
            .environmentObject(camposViewModel)
            .onAppear {
                Task {
                    await camposViewModel.loadCampos()
                }
                locationManager.requestLocation()

                if geofenceManager.autoCheckinEnabled {
                    geofenceManager.refreshWith(campos: camposViewModel.campos)
                }
            }
            .onChange(of: locationManager.authorizationStatus) { status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.requestLocation()
                }
            }
            .onChange(of: camposViewModel.campos) { _ in
                if geofenceManager.autoCheckinEnabled {
                    geofenceManager.refreshWith(campos: camposViewModel.campos)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
            .alert(isPresented: $showVerificationAlert) {
                Alert(
                    title: Text("Verificación"),
                    message: Text(verificationResult),
                    dismissButton: .default(Text("Aceptar"))
                )
            }
        }
    }

    // MARK: - Cargar campos
    // MARK: - Deep Links de Supabase (igual que tenías)
    func handleDeepLink(url: URL) {
        print("🔗 Deep link recibido: \(url)")
        guard url.scheme == "camposdegalicia" else { print("❌ Esquema no reconocido."); return }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            Task {
                do {
                    try await supabase.auth.exchangeCodeForSession(authCode: code)
                    print("✅ Sesión establecida vía exchangeCodeForSession.")
                    NotificationCenter.default.post(name: .showResetPassword, object: nil)
                } catch {
                    print("❌ exchangeCodeForSession: \(error.localizedDescription)")
                    NotificationCenter.default.post(name: .showResetPassword, object: nil)
                }
            }
            return
        }

        if url.host == "reset-password" {
            let params = parseFragmentParams(url)
            let accessToken = params["access_token"]
            let refreshToken = params["refresh_token"]

            if let access = accessToken, let refresh = refreshToken {
                Task {
                    do {
                        try await supabase.auth.setSession(accessToken: access, refreshToken: refresh)
                        print("✅ Sesión establecida desde fragmento.")
                        NotificationCenter.default.post(name: .showResetPassword, object: nil)
                    } catch {
                        print("❌ setSession: \(error.localizedDescription)")
                        NotificationCenter.default.post(name: .showResetPassword, object: nil)
                    }
                }
            } else {
                print("⚠️ Fragmento sin tokens.")
                NotificationCenter.default.post(name: .showResetPassword, object: nil)
            }
            return
        }

        if url.host == "auth",
           let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let tokenHash = queryItems.first(where: { $0.name == "token_hash" })?.value,
           let type = queryItems.first(where: { $0.name == "type" })?.value {
            print("Recibido token de verificación: \(tokenHash), tipo: \(type)")
            DispatchQueue.main.async {
                verificationResult = "Tu cuenta ha sido verificada con éxito."
                showVerificationAlert = true
            }
            return
        }

        print("❌ Enlace no reconocido o no compatible.")
    }

    func parseFragmentParams(_ url: URL) -> [String: String] {
        guard let fragment = url.fragment, !fragment.isEmpty else { return [:] }
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? ""
                params[key] = value
            }
        }
        return params
    }
}

// MARK: - Location Manager (tu clase existente sin cambios)
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
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            userLocation = nil
            isLoading = false
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
            isLoading = true
        @unknown default:
            userLocation = nil
            isLoading = false
        }
        authorizationStatus = locationManager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            userLocation = location.coordinate
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error al obtener la ubicación: \(error)")
        userLocation = nil
        isLoading = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
            isLoading = true
        default:
            userLocation = nil
            isLoading = false
        }
    }
    func requestAlwaysPermission() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            // para .denied/.restricted el camino es abrir Ajustes
            break
        }
    }
}
