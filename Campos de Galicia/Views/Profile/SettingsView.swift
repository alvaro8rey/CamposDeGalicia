import SwiftUI

/// Vista de ajustes de la aplicación
struct SettingsView: View {

    // MARK: - Environment
    @EnvironmentObject var localization: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Properties
    @ObservedObject var profileVM: ProfileViewModel
    var userId: String

    // MARK: - State
    @State private var isSaving: Bool = false
    @State private var successMessage: String? = nil
    @State private var showLanguageAlert: Bool = false
    @State private var showThemeAlert: Bool = false

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

                        // Botón Guardar Preferencias
                        saveButton
                            .padding(.horizontal)

                        // Success/Error message
                        if let successMessage = successMessage {
                            Text(successMessage)
                                .font(.callout)
                                .foregroundColor(profileVM.errorMessage != nil ? .red : .green)
                                .padding()
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
            .alert(isPresented: $showLanguageAlert) {
                Alert(
                    title: Text(L(.profileLanguageTitle)),
                    message: Text(L(.profileLanguageMessage)),
                    dismissButton: .default(Text(L(.ok)))
                )
            }
            .alert(isPresented: $showThemeAlert) {
                Alert(
                    title: Text(L(.settingsTheme)),
                    message: Text("El tema se aplicará inmediatamente"),
                    dismissButton: .default(Text(L(.ok)))
                )
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
                                    showLanguageAlert = true
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
                                    showThemeAlert = true
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
                    .disabled(isSaving)
                }

                Spacer()
            }
            .padding()
        }
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

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: { Task { await savePreferences() } }) {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isSaving ? L(.preferencesButtonSaving) : L(.preferencesButtonSave))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSaving ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isSaving)
    }

    // MARK: - Methods
    private func savePreferences() async {
        isSaving = true
        successMessage = nil

        await profileVM.savePreferences(for: userId)

        if profileVM.errorMessage == nil {
            successMessage = L(.successPreferencesSaved)
        } else {
            successMessage = profileVM.errorMessage
        }

        isSaving = false

        // Clear success message after 3 seconds
        if profileVM.errorMessage == nil {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
        }
    }

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
    }
}
