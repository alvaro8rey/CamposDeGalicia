import SwiftUI
import PhotosUI
import MapKit

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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoPreviews: [Image] = []
    @State private var coordenadas: CLLocationCoordinate2D? = nil
    @State private var showMapPicker: Bool = false
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String? = nil

    private let provincias = ["A Coruña", "Lugo", "Ourense", "Pontevedra"]
    private let maxPhotos = 3

    // MARK: - Body
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            // Toca el fondo para cerrar el teclado
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }

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
        .sheet(isPresented: $showMapPicker) {
            MapCoordinatePickerView(selectedCoordinate: $coordenadas)
        }
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
                    formRow(icon: "sportscourt.fill", iconColor: .green, label: L(.suggestFieldName)) {
                        TextField(L(.suggestFieldNamePlaceholder), text: $nombre)
                            .font(.body)
                    }

                    Divider().padding(.leading, 56)

                    // Municipio
                    formRow(icon: "building.2.fill", iconColor: .blue, label: L(.suggestMunicipality)) {
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

                    // Coordenadas (selector de mapa)
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.red)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ubicación en el mapa")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let coord = coordenadas {
                                Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.primary)
                            } else {
                                Text("Opcional")
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.placeholderText))
                            }
                        }

                        Spacer()

                        Button(action: { showMapPicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: coordenadas == nil ? "map" : "map.fill")
                                Text(coordenadas == nil ? "Seleccionar" : "Cambiar")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        if coordenadas != nil {
                            Button(action: { coordenadas = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
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

                    Divider().padding(.leading, 56)

                    // Fotos
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.cyan)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(L(.suggestPhotos))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("(\(L(.suggestPhotosOptional)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(L(.suggestPhotosMax, maxPhotos))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: maxPhotos,
                                selectionBehavior: .ordered,
                                matching: .images
                            ) {
                                Text("\(selectedPhotos.count)/\(maxPhotos)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.15))
                                    .foregroundColor(.cyan)
                                    .cornerRadius(8)
                            }
                            .onChange(of: selectedPhotos) { _, newSelection in
                                Task { await cargarPreviews(from: newSelection) }
                            }
                        }

                        if !photoPreviews.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photoPreviews.indices, id: \.self) { index in
                                        ZStack(alignment: .topTrailing) {
                                            photoPreviews[index]
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button(action: { eliminarFoto(at: index) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.red.opacity(0.8))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                            }
                        }
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
        .scrollDismissesKeyboard(.immediately)
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

    // MARK: - Photo Helpers
    private func cargarPreviews(from items: [PhotosPickerItem]) async {
        photoPreviews.removeAll()
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                photoPreviews.append(Image(uiImage: uiImage))
            }
        }
    }

    private func eliminarFoto(at index: Int) {
        selectedPhotos.remove(at: index)
        photoPreviews.remove(at: index)
    }

    private func subirFotos(userId: String) async throws -> [String] {
        var urls: [String] = []
        for (index, photoItem) in selectedPhotos.enumerated() {
            guard let data = try? await photoItem.loadTransferable(type: Data.self) else { continue }
            let fileName = "sugerencia-\(userId)-\(UUID().uuidString)-\(index).jpg"

            _ = try await supabase.storage
                .from("sugerencias-fotos")
                .upload(fileName, data: data)

            let publicURL = try supabase.storage
                .from("sugerencias-fotos")
                .getPublicURL(path: fileName)
                .absoluteString

            urls.append(publicURL)
        }
        return urls
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
            // 1. Subir fotos (si las hay)
            let imageUrls = try await subirFotos(userId: userId)

            // 2. Insertar sugerencia en base de datos
            let suggestion = SugerenciaCampo(
                userId: userId,
                nombre: nombreTrimmed,
                municipio: municipio.trimmingCharacters(in: .whitespaces).isEmpty ? nil : municipio.trimmingCharacters(in: .whitespaces),
                provincia: provincia,
                notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas.trimmingCharacters(in: .whitespaces),
                imagenes: imageUrls.isEmpty ? nil : imageUrls,
                latitud: coordenadas?.latitude,
                longitud: coordenadas?.longitude
            )

            try await supabase
                .from("sugerencias_campos")
                .insert(suggestion)
                .execute()

            // 3. Notificar por email (best-effort, no bloquea el éxito)
            struct NotificacionPayload: Encodable {
                let nombre: String
                let municipio: String
                let provincia: String
                let notas: String
                let imagenes: [String]
                let userEmail: String
                let latitud: Double?
                let longitud: Double?
            }
            try? await supabase.functions
                .invoke(
                    "notificar-sugerencia",
                    options: .init(body: NotificacionPayload(
                        nombre: nombreTrimmed,
                        municipio: municipio.trimmingCharacters(in: .whitespaces),
                        provincia: provincia,
                        notas: notas.trimmingCharacters(in: .whitespaces),
                        imagenes: imageUrls,
                        userEmail: authViewModel.user?.email ?? "",
                        latitud: coordenadas?.latitude,
                        longitud: coordenadas?.longitude
                    ))
                )

            withAnimation { showSuccess = true }
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
        selectedPhotos = []
        photoPreviews = []
        coordenadas = nil
        errorMessage = nil
        withAnimation { showSuccess = false }
    }
}

// MARK: - Model
private struct SugerenciaCampo: Encodable {
    let userId: String
    let nombre: String
    let municipio: String?
    let provincia: String
    let notas: String?
    let imagenes: [String]?
    let latitud: Double?
    let longitud: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nombre
        case municipio
        case provincia
        case notas
        case imagenes
        case latitud
        case longitud
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
