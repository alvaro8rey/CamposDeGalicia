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
    @EnvironmentObject var localization: LocalizationManager

    @StateObject private var locationPerm = LocationPermissionManager()
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var notifRequesting = false

    @State private var page = 0
    private let totalPages = 5

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    introPage.tag(0)
                    howItWorksPage.tag(1)
                    autoCheckinPage.tag(2)
                    notificationsPage.tag(3)
                    locationPermissionPage.tag(4)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
            .onChange(of: page) { newValue in
                // Actualiza el estado de los permisos cuando se llega a cada pantalla
                if newValue == 3 { // Notificaciones
                    refreshNotifStatus()
                } else if newValue == 4 { // Ubicación
                    // Solo actualiza el estado, no pide permisos automáticamente
                    locationPerm.status = CLLocationManager.authorizationStatus()
                }
            }
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
            Text(L(.onboardingWelcomeTitle))
                .font(.title2).fontWeight(.bold)
            Text(L(.onboardingWelcomeMessage))
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
            Text(L(.onboardingMissionsTitle))
                .font(.title3).fontWeight(.bold)
            VStack(alignment: .leading, spacing: 10) {
                bullet(L(.onboardingMissionsBullet1))
                bullet(L(.onboardingMissionsBullet2))
                bullet(L(.onboardingMissionsBullet3))
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 24)
    }

    private var autoCheckinPage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(L(.onboardingAutoCheckinTitle))
                .font(.title3).fontWeight(.bold)

            Text(LocalizedStringKey(L(.onboardingAutoCheckinMessage)))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                bullet(L(.onboardingAutoCheckinBullet1))
                bullet(L(.onboardingAutoCheckinBullet2))
                bullet(L(.onboardingAutoCheckinBullet3))
                bullet(L(.onboardingAutoCheckinBullet4))
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
            Text(L(.onboardingNotificationsTitle))
                .font(.title3).fontWeight(.bold)
            Text(LocalizedStringKey(L(.onboardingNotificationsMessage)))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            permissionStatusView(type: .notifications)

            // Botón para dar permisos si están no determinados
            if notifStatus == .notDetermined {
                Button(action: {
                    requestNotificationPermission()
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text(L(.onboardingNotificationsButton))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
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
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.pink)
            Text(L(.onboardingLocationTitle))
                .font(.title3).fontWeight(.bold)
            Text(LocalizedStringKey(L(.onboardingLocationMessage)))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            permissionStatusView(type: .location)

            // Botón para dar permisos si están no determinados
            if locationPerm.status == .notDetermined {
                Button(action: {
                    locationPerm.requestWhenInUse()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(L(.onboardingLocationButton))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(.top, 24)
    }

    // MARK: Bottom bar
    private var bottomBar: some View {
        HStack {
            Button(L(.skip)) {
                hasSeenOnboarding = true
                dismiss()
            }
            .foregroundColor(.secondary)

            Spacer()

            if page < totalPages - 1 {
                Button(L(.next)) {
                    withAnimation { page += 1 }
                }
                .fontWeight(.semibold)
            } else {
                Button(L(.start)) {
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
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

    private enum PermType { case location, notifications }

    private func permissionStatusView(type: PermType) -> some View {
        VStack(spacing: 8) {
            switch type {
            case .location:
                if !locationPerm.servicesEnabled {
                    Text(L(.onboardingLocationServicesDisabled))
                        .font(.footnote)
                        .foregroundColor(.orange)
                }

                switch locationPerm.status {
                case .authorizedAlways, .authorizedWhenInUse:
                    Label(L(.onboardingPermissionsGranted), systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.footnote).bold()

                case .denied, .restricted:
                    VStack(spacing: 6) {
                        Label(L(.onboardingPermissionsDenied), systemImage: "xmark.seal.fill")
                            .foregroundColor(.red)
                            .font(.footnote).bold()
                        Button(L(.onboardingOpenSettings)) {
                            locationPerm.openSettings()
                        }
                        .font(.caption).bold()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                    }

                case .notDetermined:
                    Label(L(.onboardingPermissionsNotDetermined), systemImage: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.footnote)

                @unknown default:
                    Label(L(.onboardingPermissionsUnknown), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }

            case .notifications:
                switch notifStatus {
                case .authorized, .provisional, .ephemeral:
                    Label(L(.onboardingPermissionsGranted), systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.footnote).bold()
                case .denied:
                    VStack(spacing: 6) {
                        Label(L(.onboardingPermissionsDenied), systemImage: "xmark.seal.fill")
                            .foregroundColor(.red)
                            .font(.footnote).bold()
                        Button(L(.onboardingOpenSettings)) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption).bold()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                    }
                case .notDetermined:
                    Label(L(.onboardingPermissionsNotDetermined), systemImage: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                @unknown default:
                    Label(L(.onboardingPermissionsUnknown), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .environmentObject(LocalizationManager.shared)
}

#Preview("Página de Bienvenida") {
    OnboardingView()
        .environmentObject(LocalizationManager.shared)
}

#Preview("Modo Oscuro") {
    OnboardingView()
        .environmentObject(LocalizationManager.shared)
        .preferredColorScheme(.dark)
}
