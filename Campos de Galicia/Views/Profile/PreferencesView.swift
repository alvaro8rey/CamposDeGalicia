import SwiftUI

/// Vista de preferencias del usuario
struct PreferencesView: View {

    // MARK: - Properties
    @ObservedObject var profileVM: ProfileViewModel
    var userId: String
    @State private var isSaving: Bool = false
    @State private var successMessage: String? = nil
    @EnvironmentObject var localization: LocalizationManager
    @State private var showLanguageAlert: Bool = false

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferencias")
                .font(.title3)
                .fontWeight(.bold)

            // Language Selector
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(L(.profileLanguage))
                        .font(.subheadline)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                }

                HStack(spacing: 12) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Button(action: {
                            if localization.currentLanguage != language {
                                localization.currentLanguage = language
                                showLanguageAlert = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(language.flag)
                                    .font(.title3)
                                Text(language.displayName)
                                    .font(.subheadline)
                                    .fontWeight(localization.currentLanguage == language ? .bold : .regular)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
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
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Distance Preference
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Distancia predeterminada para búsqueda de campos cercanos:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "location.circle")
                        .foregroundColor(.green)
                }

                Picker("Distancia", selection: $profileVM.distanciaPredeterminada) {
                    Text("5 km").tag(5.0)
                    Text("10 km").tag(10.0)
                    Text("20 km").tag(20.0)
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(isSaving)
            }

            // Save button
            Button(action: { Task { await savePreferences() } }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(isSaving ? "Guardando..." : "Guardar Preferencias")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSaving ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSaving)

            // Success/Error message
            if let successMessage = successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundColor(profileVM.errorMessage != nil ? .red : .green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .alert(isPresented: $showLanguageAlert) {
            Alert(
                title: Text(L(.profileLanguageTitle)),
                message: Text(L(.profileLanguageMessage)),
                dismissButton: .default(Text(L(.ok)))
            )
        }
    }

    // MARK: - Methods
    private func savePreferences() async {
        isSaving = true
        successMessage = nil

        await profileVM.savePreferences(for: userId)

        if profileVM.errorMessage == nil {
            successMessage = "✅ Preferencias guardadas con éxito"
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
}

// MARK: - Preview
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ProfileViewModel()
        PreferencesView(profileVM: vm, userId: "test-user-id")
            .environmentObject(LocalizationManager.shared)
            .padding()
    }
}
