import SwiftUI

/// Vista para que los usuarios sugieran campos que faltan en la app
struct SugerirCampoView: View {

    // MARK: - Environment
    @EnvironmentObject var localization: LocalizationManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State
    @State private var nombre: String = ""
    @State private var municipio: String = ""
    @State private var provincia: String = "A Coruña"
    @State private var notas: String = ""
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String? = nil

    private let provincias = ["A Coruña", "Lugo", "Ourense", "Pontevedra"]

    // MARK: - Body
    var body: some View {
        ZStack {
            // Fondo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if showSuccess {
                successView
            } else if !authViewModel.isAuthenticated {
                notLoggedInView
            } else {
                formView
            }
        }
        .navigationTitle(L(.settingsSuggest))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Form View
    private var formView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Subtítulo
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text(L(.suggestSubtitle))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Campos del formulario
                VStack(spacing: 0) {
                    // Nombre
                    formRow(
                        icon: "sportscourt.fill",
                        iconColor: .green,
                        label: L(.suggestFieldName)
                    ) {
                        TextField(L(.suggestFieldNamePlaceholder), text: $nombre)
                            .font(.body)
                    }

                    Divider().padding(.leading, 56)

                    // Municipio
                    formRow(
                        icon: "building.2.fill",
                        iconColor: .blue,
                        label: L(.suggestMunicipality)
                    ) {
                        TextField(L(.suggestMunicipalityPlaceholder), text: $municipio)
                            .font(.body)
                    }

                    Divider().padding(.leading, 56)

                    // Provincia
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(.suggestProvince))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker(L(.suggestProvince), selection: $provincia) {
                                ForEach(provincias, id: \.self) { p in
                                    Text(p).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.leading, -8)
                        }

                        Spacer()
                    }
                    .padding()

                    Divider().padding(.leading, 56)

                    // Notas
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text(L(.suggestNotes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        TextEditor(text: $notas)
                            .font(.body)
                            .frame(minHeight: 100, maxHeight: 160)
                            .padding(4)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                Group {
                                    if notas.isEmpty {
                                        Text(L(.suggestNotesPlaceholder))
                                            .font(.body)
                                            .foregroundColor(Color(UIColor.placeholderText))
                                            .padding(8)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                    .padding()
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Botón enviar
                Button(action: { Task { await enviar() } }) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isLoading ? L(.suggestSending) : L(.suggestSend))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(nombre.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top)
        }
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            Text(L(.suggestSuccessTitle))
                .font(.title2)
                .fontWeight(.bold)

            Text(L(.suggestSuccessMessage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: resetForm) {
                Text(L(.suggestAnotherOne))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Not Logged In View
    private var notLoggedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(L(.suggestLoginRequired))
                .font(.title3)
                .fontWeight(.bold)

            Text(L(.suggestLoginRequiredMessage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Helper: Form Row
    private func formRow<Content: View>(
        icon: String,
        iconColor: Color,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                content()
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions
    private func enviar() async {
        let nombreTrimmed = nombre.trimmingCharacters(in: .whitespaces)
        guard !nombreTrimmed.isEmpty else {
            errorMessage = L(.suggestErrorEmpty)
            return
        }

        guard let userId = authViewModel.user?.id.uuidString else {
            errorMessage = L(.suggestLoginRequired)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let suggestion = SugerenciaCampo(
                userId: userId,
                nombre: nombreTrimmed,
                municipio: municipio.trimmingCharacters(in: .whitespaces).isEmpty ? nil : municipio.trimmingCharacters(in: .whitespaces),
                provincia: provincia,
                notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas.trimmingCharacters(in: .whitespaces)
            )

            try await supabase
                .from("sugerencias_campos")
                .insert(suggestion)
                .execute()

            withAnimation {
                showSuccess = true
            }
        } catch {
            errorMessage = L(.suggestErrorGeneral)
            Logger.error("Error enviando sugerencia: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func resetForm() {
        nombre = ""
        municipio = ""
        provincia = "A Coruña"
        notas = ""
        errorMessage = nil
        withAnimation {
            showSuccess = false
        }
    }
}

// MARK: - Model
private struct SugerenciaCampo: Encodable {
    let userId: String
    let nombre: String
    let municipio: String?
    let provincia: String
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nombre
        case municipio
        case provincia
        case notas
    }
}

// MARK: - Preview
struct SugerirCampoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SugerirCampoView()
                .environmentObject(LocalizationManager.shared)
                .environmentObject(AuthViewModel.shared)
        }
    }
}
