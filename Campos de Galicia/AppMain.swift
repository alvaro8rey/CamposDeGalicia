import SwiftUI
import CoreLocation
import Supabase
import UserNotifications

extension Notification.Name {
    static let showResetPassword = Notification.Name("showResetPassword")
}

@main
struct AppMain: App {
    @State private var campos: [CampoModel] = []
    @State private var isLoading: Bool = true
    @StateObject private var locationManager = LocationManager()
    @State private var distanciaPredeterminada: Double = 10.0

    @State private var showVerificationAlert: Bool = false
    @State private var verificationResult: String = ""

    init() {
        fetchCampos()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView {
                    ContentView(
                        campos: $campos,
                        isLoading: $isLoading,
                        distanciaPredeterminada: $distanciaPredeterminada
                    )
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Inicio")
                }
                .tag(0)

                NavigationView {
                    MapaView(campos: campos)
                }
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Mapa")
                }
                .tag(1)

                NavigationView {
                    CamposCercanosView(
                        campos: $campos,
                        userLocation: $locationManager.userLocation,
                        isLoadingLocation: $locationManager.isLoading,
                        distanciaPredeterminada: $distanciaPredeterminada,
                        requestLocation: {
                            locationManager.requestLocation()
                        }
                    )
                }
                .tabItem {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Cercanos")
                }
                .tag(2)

                NavigationView {
                    UserView(
                        campos: $campos,
                        distanciaPredeterminada: $distanciaPredeterminada
                    )
                }
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Usuario")
                }
                .tag(3)
            }
            .accentColor(.blue)
            .onAppear {
                // ✅ Usa el NotificationDelegate que ya tienes en tu otro archivo
                UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

                fetchCampos()
                locationManager.requestLocation()

                // Log de estado de permisos de notificaciones (útil para depurar)
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    print("🔧 Estado de notificaciones: \(settings.authorizationStatus.rawValue)")
                }
                
            }
            .onChange(of: locationManager.authorizationStatus) { status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.requestLocation()
                }
            }
            // ✅ Manejo de enlaces de Supabase
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
    func fetchCampos() {
        print("Iniciando fetchCampos()")
        Task {
            DispatchQueue.main.async {
                isLoading = true
            }

            do {
                let response = try await supabase.from("campos").select("*").execute()
                let data = response.data
                let decoder = JSONDecoder()
                let camposResponse = try decoder.decode([CampoModel].self, from: data)

                DispatchQueue.main.async {
                    campos = camposResponse.sorted { $0.nombre.lowercased() < $1.nombre.lowercased() }
                    isLoading = false
                    print("Campos cargados: \(campos.count)")
                }
            } catch {
                print("Error al cargar campos: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Manejo de Deep Links de Supabase
    func handleDeepLink(url: URL) {
        print("🔗 Deep link recibido: \(url)")

        guard url.scheme == "camposdegalicia" else {
            print("❌ Esquema no reconocido.")
            return
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            Task {
                do {
                    try await supabase.auth.exchangeCodeForSession(authCode: code)
                    print("✅ Sesión establecida vía exchangeCodeForSession.")
                    NotificationCenter.default.post(name: .showResetPassword, object: nil)
                } catch {
                    print("❌ Error en exchangeCodeForSession: \(error.localizedDescription)")
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
                        print("❌ Error al establecer sesión desde fragmento: \(error.localizedDescription)")
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

    // MARK: - Parser del fragmento (#access_token=...)
    func parseFragmentParams(_ url: URL) -> [String: String] {
        guard let fragment = url.fragment, !fragment.isEmpty else { return [:] }

        var params: [String: String] = [:]
        let pairs = fragment.split(separator: "&")

        for pair in pairs {
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
}
