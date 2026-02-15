import SwiftUI

/// Vista de ajustes de la aplicación
struct SettingsView: View {

    // MARK: - Environment
    @EnvironmentObject var localization: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var camposViewModel: CamposViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Properties
    @ObservedObject var profileVM: ProfileViewModel
    var userId: String

    // MARK: - State
    @AppStorage("auto_checkin_enabled") private var autoCheckinStored: Bool = false
    @State private var showInfoSheet: Bool = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                        Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)

                // Contenido
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Sección General
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L(.settingsGeneral))
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // Selector de Idioma
                                languageSection

                                Divider()
                                    .padding(.leading, 56)

                                // Selector de Tema
                                themeSection

                                Divider()
                                    .padding(.leading, 56)

                                // Distancia Predeterminada
                                distanceSection

                                Divider()
                                    .padding(.leading, 56)

                                // Auto Check-in
                                autoCheckinSection
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // MARK: - Sección Información
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L(.settingsInfo))
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // Términos y Condiciones
                                NavigationLink(destination: TerminosView()) {
                                    settingsRow(
                                        icon: "doc.text.fill",
                                        iconColor: .blue,
                                        label: L(.settingsTerms)
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 56)

                                // Contacto
                                NavigationLink(destination: ContactoView()) {
                                    settingsRow(
                                        icon: "envelope.fill",
                                        iconColor: .green,
                                        label: L(.settingsContact)
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 56)

                                // Sugerir un campo
                                NavigationLink(destination: SugerirCampoView()) {
                                    settingsRow(
                                        icon: "plus.circle.fill",
                                        iconColor: .orange,
                                        label: L(.settingsSuggest)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // MARK: - Sección Cuenta
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L(.settingsAccount))
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // Botón de Cerrar Sesión
                                logoutButton
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(L(.settingsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    // MARK: - Language Section
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L(.profileLanguage))
                        .font(.body)
                        .fontWeight(.medium)

                    // Selector de idioma como botones
                    HStack(spacing: 8) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Button(action: {
                                if localization.currentLanguage != language {
                                    localization.currentLanguage = language
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(language.flag)
                                        .font(.body)
                                    Text(language.displayName)
                                        .font(.caption)
                                        .fontWeight(localization.currentLanguage == language ? .bold : .regular)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    localization.currentLanguage == language
                                        ? Color.blue
                                        : Color(UIColor.tertiarySystemBackground)
                                )
                                .foregroundColor(
                                    localization.currentLanguage == language
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Theme Section
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: themeManager.currentTheme.icon)
                    .foregroundColor(.purple)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L(.settingsTheme))
                        .font(.body)
                        .fontWeight(.medium)

                    // Selector de tema
                    HStack(spacing: 8) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button(action: {
                                if themeManager.currentTheme != theme {
                                    themeManager.currentTheme = theme
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: theme.icon)
                                        .font(.caption)
                                    Text(localization.currentLanguage == .galician ? theme.displayNameGalician : theme.displayName)
                                        .font(.caption)
                                        .fontWeight(themeManager.currentTheme == theme ? .bold : .regular)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    themeManager.currentTheme == theme
                                        ? Color.purple
                                        : Color(UIColor.tertiarySystemBackground)
                                )
                                .foregroundColor(
                                    themeManager.currentTheme == theme
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Distance Section
    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "location.circle")
                    .foregroundColor(.green)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L(.preferencesDistance))
                        .font(.body)
                        .fontWeight(.medium)

                    Picker("Distancia", selection: $profileVM.distanciaPredeterminada) {
                        Text(L(.preferencesDistanceKm, 5)).tag(5.0)
                        Text(L(.preferencesDistanceKm, 10)).tag(10.0)
                        Text(L(.preferencesDistanceKm, 20)).tag(20.0)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: profileVM.distanciaPredeterminada) { oldValue, newValue in
                        Task {
                            await profileVM.savePreferences(for: userId)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Auto Check-in Section
    private var autoCheckinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "location.fill.viewfinder")
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(L(.profileAutoCheckin))
                            .font(.body)
                            .fontWeight(.medium)

                        Button(action: { showInfoSheet = true }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }

                    Text(L(.profileAutoCheckinDesc))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if locationManager.authorizationStatus != .authorizedAlways && autoCheckinStored {
                        Text(L(.profileAutoCheckinWarning))
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)

                        if locationManager.authorizationStatus == .authorizedWhenInUse {
                            Button {
                                geofenceManager.requestAlwaysAuthorization()
                            } label: {
                                Text(L(.profileAutoCheckinInfoReqAlways))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.top, 2)
                        } else {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(L(.onboardingOpenSettings))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                Spacer()

                Toggle("", isOn: $autoCheckinStored)
                    .labelsHidden()
                    .onChange(of: autoCheckinStored) { oldValue, newValue in
                        geofenceManager.setAutoCheckin(newValue, campos: camposViewModel.campos)
                        if newValue {
                            Logger.info("✅ Auto check-in activado")
                        } else {
                            Logger.info("⏹ Auto check-in desactivado")
                        }
                    }
            }
            .padding()
        }
        .sheet(isPresented: $showInfoSheet) {
            InfoSheetView()
        }
    }

    // MARK: - Settings Row Helper
    private func settingsRow(icon: String, iconColor: Color, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Logout Button
    private var logoutButton: some View {
        Button(action: { Task { await logout() } }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                    .frame(width: 24)

                Text(L(.profileLogout))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.red)

                Spacer()
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Methods
    private func logout() async {
        do {
            try await authViewModel.logout()
            dismiss()
        } catch {
            profileVM.errorMessage = L(.errorLogout, error.localizedDescription)
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ProfileViewModel()
        SettingsView(profileVM: vm, userId: "test-user-id")
            .environmentObject(LocalizationManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(AuthViewModel.shared)
            .environmentObject(GeofenceManager())
            .environmentObject(LocationManager())
            .environmentObject(CamposViewModel())
    }
}
