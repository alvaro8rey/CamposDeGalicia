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
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @EnvironmentObject var localization: LocalizationManager
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var authViewModel: AuthViewModel

    @StateObject private var locationPerm = LocationPermissionManager()
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    // Account creation state
    @State private var regNombre: String = ""
    @State private var regApellidos: String = ""
    @State private var regEmail: String = ""
    @State private var regPassword: String = ""
    @State private var regError: String? = nil
    @State private var regLoading: Bool = false
    @State private var regSuccess: Bool = false

    @State private var page = 0
    private let totalPages = 5

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.06),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.04)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: index == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Content
                TabView(selection: $page) {
                    settingsPage.tag(0)
                    welcomePage.tag(1)
                    featuresPage.tag(2)
                    permissionsPage.tag(3)
                    accountPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom bar
                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onChange(of: page) { _, newValue in
            if newValue == 3 {
                refreshNotifStatus()
                locationPerm.status = CLLocationManager.authorizationStatus()
            }
        }
        .onAppear {
            refreshNotifStatus()
        }
    }

    // MARK: - Page 0: Language & Theme

    private var settingsPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text(L(.onboardingSettingsTitle))
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Language selection
                VStack(alignment: .leading, spacing: 12) {
                    Label(L(.onboardingSettingsLanguage), systemImage: "globe")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        languageButton(language: .spanish, flag: "🇪🇸", name: "Castellano")
                        languageButton(language: .galician, flag: "🏴", name: "Galego")
                    }
                }
                .padding(.horizontal, 24)

                // Theme selection
                VStack(alignment: .leading, spacing: 12) {
                    Label(L(.onboardingSettingsTheme), systemImage: "circle.lefthalf.filled")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            themeButton(theme: theme)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .scrollIndicators(.hidden)
    }

    private func languageButton(language: Language, flag: String, name: String) -> some View {
        let isSelected = localization.currentLanguage == language
        return Button {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                localization.currentLanguage = language
            }
        } label: {
            HStack(spacing: 10) {
                Text(flag).font(.title2)
                Text(name)
                    .font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(14)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func themeButton(theme: AppTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let name = localization.currentLanguage == .galician ? theme.displayNameGalician : theme.displayName
        return Button {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                themeManager.currentTheme = theme
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: theme.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                Text(name)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 12) {
                Text(L(.onboardingWelcomeTitle))
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(L(.onboardingWelcomeMessage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text(L(.onboardingFeaturesTitle))
                    .font(.title2).fontWeight(.bold)

                VStack(spacing: 14) {
                    featureRow(icon: "location.circle.fill", color: .green, text: L(.onboardingFeaturesBullet1))
                    featureRow(icon: "star.circle.fill", color: .orange, text: L(.onboardingFeaturesBullet2))
                    featureRow(icon: "text.bubble.fill", color: .blue, text: L(.onboardingFeaturesBullet3))
                    featureRow(icon: "map.circle.fill", color: .purple, text: L(.onboardingFeaturesBullet4))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .scrollIndicators(.hidden)
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Page 3: Permissions

    private var permissionsPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                VStack(spacing: 12) {
                    Text(L(.onboardingPermissionsTitle))
                        .font(.title2).fontWeight(.bold)

                    Text(L(.onboardingPermissionsMessage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 14) {
                    // Location permission card
                    permissionCard(
                        icon: "location.fill",
                        color: .pink,
                        title: L(.onboardingLocationTitle),
                        status: locationPermissionStatus,
                        statusColor: locationPermissionColor,
                        action: locationPerm.status == .notDetermined ? {
                            locationPerm.requestWhenInUse()
                        } : (locationPerm.status == .denied || locationPerm.status == .restricted ? {
                            locationPerm.openSettings()
                        } : nil)
                    )

                    // Notification permission card
                    permissionCard(
                        icon: "bell.fill",
                        color: .purple,
                        title: L(.onboardingNotificationsTitle),
                        status: notificationPermissionStatus,
                        statusColor: notificationPermissionColor,
                        action: notifStatus == .notDetermined ? {
                            requestNotificationPermission()
                        } : (notifStatus == .denied ? {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } : nil)
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .scrollIndicators(.hidden)
    }

    private func permissionCard(icon: String, color: Color, title: String, status: String, statusColor: Color, action: (() -> Void)?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Label(status, systemImage: statusColor == .green ? "checkmark.circle.fill" : (statusColor == .red ? "xmark.circle.fill" : "questionmark.circle"))
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            Spacer()

            if let action = action {
                Button {
                    HapticFeedback.light()
                    action()
                } label: {
                    Text(statusColor == .red ? L(.onboardingOpenSettings) : L(.onboardingNotificationsButton).split(separator: " ").last.map(String.init) ?? "Permitir")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(color)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var locationPermissionStatus: String {
        switch locationPerm.status {
        case .authorizedAlways, .authorizedWhenInUse: return L(.onboardingPermissionsGranted)
        case .denied, .restricted: return L(.onboardingPermissionsDenied)
        case .notDetermined: return L(.onboardingPermissionsNotDetermined)
        @unknown default: return L(.onboardingPermissionsUnknown)
        }
    }

    private var locationPermissionColor: Color {
        switch locationPerm.status {
        case .authorizedAlways, .authorizedWhenInUse: return .green
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }

    private var notificationPermissionStatus: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return L(.onboardingPermissionsGranted)
        case .denied: return L(.onboardingPermissionsDenied)
        case .notDetermined: return L(.onboardingPermissionsNotDetermined)
        @unknown default: return L(.onboardingPermissionsUnknown)
        }
    }

    private var notificationPermissionColor: Color {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        default: return .secondary
        }
    }

    // MARK: - Page 4: Account

    private var accountPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 12)

                if regSuccess {
                    // Success state
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))

                    Text(L(.onboardingAccountSuccess))
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.green)

                    Text(L(.onboardingAccountSuccessMessage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    // Header
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.linearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text(L(.onboardingAccountTitle))
                        .font(.title2).fontWeight(.bold)

                    Text(L(.onboardingAccountMessage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Registration form
                    VStack(spacing: 12) {
                        // Name fields in HStack
                        HStack(spacing: 10) {
                            formField(
                                icon: "person.fill",
                                placeholder: L(.registerNamePlaceholder),
                                text: $regNombre
                            )
                            .autocapitalization(.words)

                            formField(
                                icon: "person.fill",
                                placeholder: L(.registerSurnamePlaceholder),
                                text: $regApellidos
                            )
                            .autocapitalization(.words)
                        }

                        // Email
                        formField(
                            icon: "envelope.fill",
                            placeholder: L(.loginEmailPlaceholder),
                            text: $regEmail
                        )
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                        // Password
                        SecureFormField(
                            icon: "lock.fill",
                            placeholder: "********",
                            text: $regPassword
                        )

                        // Password hint
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text(L(.registerPasswordHint))
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Error message
                        if let error = regError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text(error)
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Create account button
                        Button {
                            Task { await createAccount() }
                        } label: {
                            HStack(spacing: 8) {
                                if regLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(regLoading ? L(.onboardingAccountCreating) : L(.onboardingAccountCreateButton))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: isRegFormValid ? [.green, .mint] : [.gray.opacity(0.4), .gray.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isRegFormValid || regLoading)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var isRegFormValid: Bool {
        !regNombre.trimmingCharacters(in: .whitespaces).isEmpty &&
        !regApellidos.trimmingCharacters(in: .whitespaces).isEmpty &&
        !regEmail.trimmingCharacters(in: .whitespaces).isEmpty &&
        !regPassword.isEmpty
    }

    private func formField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(.subheadline)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(regLoading)
    }

    private func createAccount() async {
        regError = nil
        regLoading = true
        HapticFeedback.light()

        do {
            _ = try await authViewModel.register(
                email: regEmail.trimmingCharacters(in: .whitespaces),
                password: regPassword,
                nombre: regNombre.trimmingCharacters(in: .whitespaces),
                apellidos: regApellidos.trimmingCharacters(in: .whitespaces)
            )
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                regSuccess = true
            }
            HapticFeedback.success()
        } catch {
            regError = error.localizedDescription
            HapticFeedback.error()
        }

        regLoading = false
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if page > 0 {
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        page -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
            }

            Spacer()

            if page == 0 {
                Button(L(.skip)) {
                    hasSeenOnboarding = true
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            if page < totalPages - 1 {
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        page += 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(L(.next))
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            } else {
                // Last page: "Skip" to enter without account, or "Start" if account created
                if !regSuccess {
                    Button {
                        HapticFeedback.light()
                        hasSeenOnboarding = true
                        dismiss()
                    } label: {
                        Text(L(.onboardingAccountSkip))
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }

                if regSuccess {
                    Button {
                        HapticFeedback.light()
                        hasSeenOnboarding = true
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Text(L(.start))
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
}

// MARK: - SecureFormField
private struct SecureFormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            SecureField(placeholder, text: $text)
                .font(.subheadline)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .environmentObject(LocalizationManager.shared)
        .environmentObject(AuthViewModel.shared)
}

#Preview("Modo Oscuro") {
    OnboardingView()
        .environmentObject(LocalizationManager.shared)
        .environmentObject(AuthViewModel.shared)
        .preferredColorScheme(.dark)
}
