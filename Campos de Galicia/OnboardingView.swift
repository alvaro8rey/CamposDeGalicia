import SwiftUI
import CoreLocation
import UserNotifications

// MARK: - Location Permission Manager
final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var servicesEnabled: Bool = CLLocationManager.locationServicesEnabled()

    override init() {
        super.init()
        manager.delegate = self
        self.status = CLLocationManager.authorizationStatus()
    }

    func requestWhenInUse() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            self.status = CLLocationManager.authorizationStatus()
            self.servicesEnabled = CLLocationManager.locationServicesEnabled()
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.status = CLLocationManager.authorizationStatus()
            self.servicesEnabled = CLLocationManager.locationServicesEnabled()
        }
    }
}

// MARK: - OnboardingView
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    @StateObject private var locationPerm = LocationPermissionManager()
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var notifRequesting = false

    @State private var page = 0
    private let totalPages = 4

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    introPage.tag(0)
                    howItWorksPage.tag(1)
                    notificationsPage.tag(2)
                    locationPermissionPage.tag(3)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
            .onAppear {
                refreshNotifStatus()
            }
        }
    }

    // MARK: Pages
    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 10)
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)
            Text("¡Bienvenido a Campos de Galicia!")
                .font(.title2).fontWeight(.bold)
            Text("Descubre, visita y marca campos reales. Completa misiones y gana XP por tu actividad.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 24)
    }

    private var howItWorksPage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Misiones y XP")
                .font(.title3).fontWeight(.bold)
            VStack(alignment: .leading, spacing: 10) {
                bullet("Marca campos como visitados cuando estés **a 500 m** del campo.")
                bullet("Completa misiones por número de campos y **rachas de días**.")
                bullet("La XP sube por niveles. ¡Explora y progresa!")
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 24)
    }

    private var notificationsPage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundColor(.purple)
            Text("Permitir notificaciones")
                .font(.title3).fontWeight(.bold)
            Text("Te avisaremos cuando tu **recompensa diaria** esté lista. Puedes activarlas ahora o más tarde en Ajustes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Estado
            permissionStatusView(type: .notifications)

            // Botón
            if notifStatus == .notDetermined {
                Button {
                    requestNotificationPermission()
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                        Text("Permitir notificaciones")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 2, y: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .disabled(notifRequesting)
            } else if notifStatus == .authorized || notifStatus == .provisional || notifStatus == .ephemeral {
                Button {
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Notificaciones activadas")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .disabled(true)
            } else {
                Button {
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Abrir Ajustes")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 2, y: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(.top, 24)
    }

    private var locationPermissionPage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.pink)
            Text("Permitir ubicación")
                .font(.title3).fontWeight(.bold)
            Text("Usamos tu ubicación **solo** para verificar que estás cerca del campo y así registrar visitas reales (evita marcar campos desde casa).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                locationPerm.requestWhenInUse()
            } label: {
                HStack {
                    Image(systemName: locationPerm.status == .authorizedWhenInUse || locationPerm.status == .authorizedAlways ? "checkmark.circle.fill" : "location.fill")
                    Text(locationPerm.status == .authorizedWhenInUse || locationPerm.status == .authorizedAlways ? "Permiso concedido" : "Permitir ubicación")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    locationPerm.status == .authorizedWhenInUse || locationPerm.status == .authorizedAlways
                        ? Color.green.opacity(0.25)
                        : Color.blue
                )
                .foregroundColor(
                    locationPerm.status == .authorizedWhenInUse || locationPerm.status == .authorizedAlways
                        ? .green
                        : .white
                )
                .cornerRadius(12)
                .shadow(radius: 2, y: 1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .disabled(locationPerm.status == .authorizedWhenInUse || locationPerm.status == .authorizedAlways)

            permissionStatusView(type: .location)

            Spacer()
        }
        .padding(.top, 24)
    }

    // MARK: Bottom bar
    private var bottomBar: some View {
        HStack {
            Button("Saltar") {
                hasSeenOnboarding = true
                dismiss()
            }
            .foregroundColor(.secondary)

            Spacer()

            if page < totalPages - 1 {
                Button("Siguiente") {
                    withAnimation { page += 1 }
                }
                .fontWeight(.semibold)
            } else {
                Button("Empezar") {
                    hasSeenOnboarding = true
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: Helpers
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(LocalizedStringKey(text))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requestNotificationPermission() {
        notifRequesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notifRequesting = false
                refreshNotifStatus()
            }
        }
    }

    private func refreshNotifStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notifStatus = settings.authorizationStatus
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private enum PermType { case location, notifications }

    private func permissionStatusView(type: PermType) -> some View {
        VStack(spacing: 8) {
            switch type {
            case .location:
                if !locationPerm.servicesEnabled {
                    Text("Servicios de localización desactivados")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }

                switch locationPerm.status {
                case .authorizedAlways, .authorizedWhenInUse:
                    Label("Permisos otorgados", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.footnote).bold()

                case .denied, .restricted:
                    VStack(spacing: 6) {
                        Label("Permisos denegados", systemImage: "xmark.seal.fill")
                            .foregroundColor(.red)
                            .font(.footnote).bold()
                        Button("Abrir Ajustes") {
                            locationPerm.openSettings()
                        }
                        .font(.caption).bold()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                    }

                case .notDetermined:
                    Label("Permiso no determinado", systemImage: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.footnote)

                @unknown default:
                    Label("Estado desconocido", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }

            case .notifications:
                switch notifStatus {
                case .authorized, .provisional, .ephemeral:
                    Label("Permisos otorgados", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.footnote).bold()
                case .denied:
                    VStack(spacing: 6) {
                        Label("Permisos denegados", systemImage: "xmark.seal.fill")
                            .foregroundColor(.red)
                            .font(.footnote).bold()
                        Button("Abrir Ajustes") {
                            openSettings()
                        }
                        .font(.caption).bold()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                    }
                case .notDetermined:
                    Label("Permiso no determinado", systemImage: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                @unknown default:
                    Label("Estado desconocido", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
