import SwiftUI
import Supabase
import PhotosUI
import CoreLocation

struct CampoContribucion: Encodable {
    let id_usuario: String
    let id_campo: String
    let fotos_adicionales: [String]?
    let tiene_cantina: Bool?
    let aforo_grada: Int?
    let medidas_campo: String?
    let tipo_iluminacion: String?
    let estado_cesped: String?
    let accesibilidad: String?
    let notas: String?
    let fecha: Date
    let aprobada: Bool
}

struct ContribucionAprobada: Codable, Equatable {
    let id_usuario: String
    let fotos_adicionales: [String]?
    let tiene_cantina: Bool?
    let aforo_grada: Int?
    let medidas_campo: String?
    let tipo_iluminacion: String?
    let estado_cesped: String?
    let accesibilidad: String?
    let notas: String?
}

struct UserProfile: Decodable {
    let id: String?
    let nombre: String
}

struct CampoDetalleView: View {
    let campoID: UUID
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var campo: CampoModel?
    @Environment(\.colorScheme) var colorScheme
    @State private var errorMessage: String? = nil
    @State private var isVisited: Bool = false
    @State private var showingContribucionForm: Bool = false
    @State private var contribucionesAprobadas: [ContribucionAprobada] = []
    @State private var userNames: [String: String] = [:]
    @State private var showingImageViewer: Bool = false
    @State private var selectedPhotoIndex: Int = 0
    @State private var showLocationAlert = false
    @State private var locationAlertMessage = ""
    @State private var showVisitSuccessAlert = false
    @State private var visitSuccessMessage = ""

    // Parámetros de validación de visita por proximidad
    private let visitRadiusMeters: CLLocationDistance = 500 // radio permitido
    private let maxAllowedAccuracy: CLLocationAccuracy = 100 // precisión mínima aceptable

    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    private var campoValue: CampoModel? {
        campo ?? camposViewModel.campo(with: campoID)
    }

    private func syncCampo() {
        campo = camposViewModel.campo(with: campoID)
    }

    var body: some View {
        Group {
            if let campo = campo {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero Image
                        GeometryReader { geometry in
                            ZStack(alignment: .bottomLeading) {
                                let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                                if let url = URL(string: imageURL) {
                                    CachedAsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geometry.size.width, height: 220)
                                            .clipped()
                                    } placeholder: {
                                        ZStack {
                                            Color.gray.opacity(0.1)
                                            ProgressView()
                                        }
                                        .frame(width: geometry.size.width, height: 220)
                                    }
                                }

                            // Visit Badge
                            if supabase.auth.currentUser != nil {
                                Button(action: {
                                    Task {
                                        if isVisited {
                                            await unmarkAsVisited()
                                        } else {
                                            await markVisitWithProximityCheck()
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isVisited ? "checkmark.circle.fill" : "mappin.circle.fill")
                                            .font(.caption)
                                        Text(isVisited ? "Visitado" : "Marcar visita")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background((isVisited ? Color.green : Color.blue).opacity(0.92))
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.25), radius: 4)
                                }
                                .padding(16)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        }
                        .frame(height: 220)

                        // Header Section (nombre + contribuir)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(campo.nombre)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            if supabase.auth.currentUser != nil {
                                Button(action: {
                                    showingContribucionForm = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle")
                                            .font(.caption)
                                        Text("Contribuir")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // UBICACIÓN
                        sectionContainer {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionHeader("Ubicación", systemImage: "mappin.circle.fill")

                                VStack(alignment: .leading, spacing: 10) {
                                    detailRow("Localidad:", campo.localidad)
                                    detailRow("Provincia:", campo.provincia)
                                    detailRow("Dirección:", campo.direccion)
                                    detailRow("Código Postal:", campo.codigo_postal)
                                }

                                if let lat = campo.latitud, let lon = campo.longitud {
                                    Button(action: {
                                        let googleMapsURL = URL(string: "comgooglemaps://?saddr=&daddr=\(lat),\(lon)&directionsmode=driving")
                                        if let url = googleMapsURL, UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url)
                                        } else {
                                            let webUrlString = "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=driving"
                                            if let webUrl = URL(string: webUrlString) {
                                                UIApplication.shared.open(webUrl)
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "map.fill")
                                                .font(.title3)
                                            Text("Cómo llegar")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .blue.opacity(0.3), radius: 6)
                                    }
                                }
                            }
                        }

                        // DETALLES DEL CAMPO
                        sectionContainer {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionHeader("Detalles", systemImage: "info.circle.fill")

                                VStack(alignment: .leading, spacing: 10) {
                                    detailRow("Superficie:", campo.superficie)
                                    detailRow("Tipo de campo:", campo.tipo)

                                    if let contribucion = contribucionesAprobadas.first {
                                        optionalDetailRow("Tiene cantina:", contribucion.tiene_cantina.map { $0 ? "Sí" : "No" })
                                        optionalDetailRow("Aforo de la grada:", contribucion.aforo_grada.map { "\($0)" })
                                        optionalDetailRow("Medidas del campo:", contribucion.medidas_campo)
                                        optionalDetailRow("Tipo de iluminación:", contribucion.tipo_iluminacion)
                                        optionalDetailRow("Estado del césped:", contribucion.estado_cesped)
                                        optionalDetailRow("Accesibilidad:", contribucion.accesibilidad)
                                        optionalDetailRow("Notas adicionales:", contribucion.notas)
                                    }
                                }
                            }
                        }

                        // Fotos adicionales
                        if !contribucionesAprobadas.isEmpty {
                            let todasLasFotos: [(url: String, userId: String)] = contribucionesAprobadas.flatMap { contribucion in
                                (contribucion.fotos_adicionales ?? []).map { url in
                                    (url: url, userId: contribucion.id_usuario)
                                }
                            }

                            if !todasLasFotos.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    sectionHeader("Fotos", systemImage: "photo.stack.fill")
                                        .padding(.horizontal, 16)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(todasLasFotos.indices, id: \.self) { index in
                                                let foto = todasLasFotos[index]
                                                let nombre = userNames[foto.userId] ?? "Usuario desconocido"

                                                VStack(spacing: 8) {
                                                    if let url = URL(string: foto.url) {
                                                        CachedAsyncImage(url: url) { image in
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 130, height: 130)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                .shadow(color: .black.opacity(0.15), radius: 4)
                                                        } placeholder: {
                                                            ZStack {
                                                                Color.gray.opacity(0.2)
                                                                ProgressView()
                                                            }
                                                            .frame(width: 130, height: 130)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        }
                                                        .onTapGesture {
                                                            selectedPhotoIndex = index
                                                            showingImageViewer = true
                                                        }
                                                    }

                                                    Text("Por \(nombre)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        }

                        // RESEÑAS SECTION
                        ReviewsSectionView(
                            campoId: campoID,
                            campoNombre: campo.nombre
                        )
                        .environmentObject(authViewModel)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)

                        Spacer(minLength: 60)
                    }
                }
                .background(Color(UIColor.systemBackground))
            } else {
                LoadingView(message: "Cargando información del campo...", style: .shimmer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(campo?.nombre ?? "Campo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContribucionForm) {
            if let campo = campoValue {
                ContribucionFormView(campo: campo, onSubmit: { contribucion in
                    Task {
                        await submitContribucion(contribucion)
                    }
                })
            }
        }
        .sheet(isPresented: $showingImageViewer) {
            if let todasLasFotos = getAllPhotos(), !todasLasFotos.isEmpty {
                ImageGalleryViewer(photos: todasLasFotos, initialIndex: selectedPhotoIndex)
            }
        }
        .onAppear {
            syncCampo()
            if let extras = camposViewModel.extras(for: campoID) {
                contribucionesAprobadas = extras.contribuciones
                Task { await preloadUserNames(for: extras.contribuciones) }
            }
            Task {
                await checkIfVisited()
                await fetchContribucionesAprobadas(forceRefresh: false)
            }
        }
        .onChange(of: camposViewModel.campos) { _ in
            syncCampo()
        }
        .alert(isPresented: $showLocationAlert) {
            Alert(
                title: Text("No se pudo marcar la visita"),
                message: Text(locationAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showVisitSuccessAlert) {
            Alert(
                title: Text("✅ ¡Éxito!"),
                message: Text(visitSuccessMessage),
                dismissButton: .default(Text("OK")) {
                    // Clear error message if any
                    errorMessage = nil
                }
            )
        }
    }

    // MARK: - Helpers de UI reutilizables

    @ViewBuilder
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(.blue)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .fixedSize()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func optionalDetailRow(_ label: String, _ value: String?) -> some View {
        if let value {
            detailRow(label, value)
        }
    }

    // MARK: - Funciones de lógica (sin cambios)

    private func markVisitWithProximityCheck() async {
        guard let campo = campoValue, let lat = campo.latitud, let lon = campo.longitud else {
            locationAlertMessage = "Este campo no tiene coordenadas válidas."
            showLocationAlert = true
            return
        }

        guard let userLoc = await LocationService.shared.requestCurrentLocation() else {
            locationAlertMessage = "No pudimos obtener tu ubicación. Activa los permisos de localización."
            showLocationAlert = true
            return
        }

        if userLoc.horizontalAccuracy < 0 || userLoc.horizontalAccuracy > maxAllowedAccuracy {
            locationAlertMessage = "La señal de GPS es poco precisa ahora mismo. Inténtalo de nuevo al aire libre."
            showLocationAlert = true
            return
        }

        let fieldLoc = CLLocation(latitude: lat, longitude: lon)
        let distance = userLoc.distance(from: fieldLoc)

        if distance <= visitRadiusMeters {
            await markAsVisited()
        } else {
            let pretty = formatDistance(distance)
            let radiusPretty = formatDistance(visitRadiusMeters)
            locationAlertMessage = "Estás a ~\(pretty) del campo. Acércate (≤ \(radiusPretty)) para marcar la visita."
            showLocationAlert = true
        }
    }

    private func checkIfVisited() async {
        guard let currentUser = supabase.auth.currentUser else { return }
        guard let campo = campoValue else { return }

        do {
            let response = try await supabase.from("visitas")
                .select("id_campo")
                .eq("id_usuario", value: currentUser.id.uuidString)
                .eq("id_campo", value: campo.id.uuidString)
                .execute()

            if let array = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
               !array.isEmpty {
                isVisited = true
            } else {
                isVisited = false
            }
        } catch {
            print("Error checking visit:", error)
        }
    }

    private func markAsVisited() async {
        guard let currentUser = supabase.auth.currentUser else { return }
        guard let campo = campoValue else { return }

        do {
            let visita: [String: String] = [
                "id_usuario": currentUser.id.uuidString,
                "id_campo": campo.id.uuidString
            ]
            _ = try await supabase.from("visitas").insert(visita).execute()
            isVisited = true
            visitSuccessMessage = "¡Has visitado \(campo.nombre)!"
            showVisitSuccessAlert = true
            NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
        } catch {
            errorMessage = "Error al registrar visita"
            print(error)
        }
    }

    private func unmarkAsVisited() async {
        guard let currentUser = supabase.auth.currentUser else { return }
        guard let campo = campoValue else { return }

        do {
            _ = try await supabase.from("visitas")
                .delete()
                .eq("id_usuario", value: currentUser.id.uuidString)
                .eq("id_campo", value: campo.id.uuidString)
                .execute()
            isVisited = false
            visitSuccessMessage = "Visita desmarcada"
            showVisitSuccessAlert = true
            NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
        } catch {
            errorMessage = "Error al desmarcar visita"
            print(error)
        }
    }

    private func fetchContribucionesAprobadas(forceRefresh: Bool) async {
        do {
            let extras = try await camposViewModel.loadExtras(for: campoID, forceRefresh: forceRefresh)
            contribucionesAprobadas = extras.contribuciones
            await preloadUserNames(for: extras.contribuciones)
        } catch {
            print("Error fetching contribuciones:", error)
        }
    }

    private func preloadUserNames(for contribuciones: [ContribucionAprobada]) async {
        let uniqueUserIds = Array(Set(contribuciones.map { $0.id_usuario }))
        guard !uniqueUserIds.isEmpty else { return }

        do {
            let response = try await supabase.from("perfiles")
                .select("id, nombre")
                .in("id", values: uniqueUserIds)
                .execute()

            let profiles = try JSONDecoder().decode([UserProfile].self, from: response.data)
            for profile in profiles {
                if let id = profile.id {
                    userNames[id] = profile.nombre
                }
            }
            // Fallback
            for id in uniqueUserIds where userNames[id] == nil {
                userNames[id] = "Usuario desconocido"
            }
        } catch {
            print("Error loading user names:", error)
            for id in uniqueUserIds {
                userNames[id] = "Usuario desconocido"
            }
        }
    }

    private func submitContribucion(_ contribucion: CampoContribucion) async {
        guard let campo = campoValue else { return }
        do {
            _ = try await supabase.from("campo_contribuciones").insert(contribucion).execute()
            errorMessage = "Contribución enviada con éxito. ¡Gracias!"
            showingContribucionForm = false
            camposViewModel.invalidateExtras(for: campoID)
            await fetchContribucionesAprobadas(forceRefresh: true)
        } catch {
            errorMessage = "Error al enviar contribución"
            print(error)
        }
    }

    private func getAllPhotos() -> [(url: String, userId: String)]? {
        let todasLasFotos = contribucionesAprobadas.flatMap { contribucion in
            (contribucion.fotos_adicionales ?? []).map { url in
                (url: url, userId: contribucion.id_usuario)
            }
        }
        return todasLasFotos.isEmpty ? nil : todasLasFotos
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            return km >= 10 ? String(format: "%.0f km", km) : String(format: "%.1f km", km)
        } else {
            return "\(Int(meters.rounded())) m"
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Resto del archivo sin cambios (formulario y visor de imágenes)
// ────────────────────────────────────────────────────────────────────────────

struct ContribucionFormView: View {
    let campo: CampoModel
    let onSubmit: (CampoContribucion) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoPreviews: [Image] = []
    @State private var tieneCantina: Bool = false
    @State private var aforoGrada: String = ""
    @State private var medidasCampo: String = ""
    @State private var tipoIluminacion: String = ""
    @State private var estadoCesped: String = ""
    @State private var accesibilidad: String = ""
    @State private var notas: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información adicional para \(campo.nombre)")) {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        selectionBehavior: .ordered,
                        matching: .images
                    ) {
                        Label("Añadir fotos", systemImage: "photo.on.rectangle.angled")
                            .foregroundColor(.blue)
                    }
                    .onChange(of: selectedPhotos) { newSelection in
                        Task {
                            await loadPhotoPreviews(from: newSelection)
                        }
                    }

                    if !photoPreviews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(photoPreviews.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        photoPreviews[index]
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                            .padding(.vertical, 4)

                                        Button(action: {
                                            removePhoto(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 5, y: -5)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Toggle("¿Tiene cantina?", isOn: $tieneCantina)

                    TextField("Aforo de la grada (número)", text: $aforoGrada)
                        .keyboardType(.numberPad)

                    TextField("Medidas del campo (ej. 105x68 metros)", text: $medidasCampo)

                    Picker("Tipo de iluminación", selection: $tipoIluminacion) {
                        Text("Seleccionar").tag("")
                        Text("Natural").tag("Natural")
                        Text("Artificial").tag("Artificial")
                    }

                    Picker("Estado del césped", selection: $estadoCesped) {
                        Text("Seleccionar").tag("")
                        Text("Bueno").tag("Bueno")
                        Text("Regular").tag("Regular")
                        Text("Malo").tag("Malo")
                    }

                    Picker("Accesibilidad", selection: $accesibilidad) {
                        Text("Seleccionar").tag("")
                        Text("Sí, tiene acceso para discapacitados").tag("Sí, tiene acceso para discapacitados")
                        Text("No, no tiene acceso").tag("No, no tiene acceso")
                    }

                    TextEditor(text: $notas)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Aportar información")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        Task { await submitForm() }
                    }
                    .disabled(!isFormValid())
                }
            }
        }
    }

    private func isFormValid() -> Bool {
        !selectedPhotos.isEmpty ||
        tieneCantina ||
        !aforoGrada.isEmpty ||
        !medidasCampo.isEmpty ||
        !tipoIluminacion.isEmpty ||
        !estadoCesped.isEmpty ||
        !accesibilidad.isEmpty ||
        !notas.isEmpty
    }

    private func loadPhotoPreviews(from items: [PhotosPickerItem]) async {
        photoPreviews.removeAll()
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    photoPreviews.append(Image(uiImage: uiImage))
                }
            } catch {
                print("Error loading photo preview:", error)
            }
        }
    }

    private func removePhoto(at index: Int) {
        selectedPhotos.remove(at: index)
        photoPreviews.remove(at: index)
    }

    private func uploadPhotos() async throws -> [String]? {
        guard !selectedPhotos.isEmpty else { return nil }
        var uploadedURLs: [String] = []

        for (index, item) in selectedPhotos.enumerated() {
            guard let data = try await item.loadTransferable(type: Data.self) else { continue }

            let fileName = "\(campo.id.uuidString)-\(UUID().uuidString)-photo-\(index).jpg"
            let filePath = "fotos-campos/\(fileName)"

            _ = try await supabase.storage.from("fotos-campos").upload(path: fileName, file: data)

            let publicURL = try supabase.storage.from("fotos-campos").getPublicURL(path: fileName).absoluteString
            uploadedURLs.append(publicURL)
        }

        return uploadedURLs.isEmpty ? nil : uploadedURLs
    }

    private func submitForm() async {
        guard let currentUser = supabase.auth.currentUser else { return }

        do {
            let fotosURLs = try await uploadPhotos()

            let contribucion = CampoContribucion(
                id_usuario: currentUser.id.uuidString,
                id_campo: campo.id.uuidString,
                fotos_adicionales: fotosURLs,
                tiene_cantina: tieneCantina ? true : nil,
                aforo_grada: Int(aforoGrada),
                medidas_campo: medidasCampo.isEmpty ? nil : medidasCampo,
                tipo_iluminacion: tipoIluminacion.isEmpty ? nil : tipoIluminacion,
                estado_cesped: estadoCesped.isEmpty ? nil : estadoCesped,
                accesibilidad: accesibilidad.isEmpty ? nil : accesibilidad,
                notas: notas.isEmpty ? nil : notas,
                fecha: Date(),
                aprobada: false
            )

            onSubmit(contribucion)
            dismiss()
        } catch {
            print("Error submitting contribution:", error)
        }
    }
}

struct ImageGalleryViewer: View {
    let photos: [(url: String, userId: String)]
    let initialIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int

    init(photos: [(url: String, userId: String)], initialIndex: Int) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationView {
            TabView(selection: $currentIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    if let url = URL(string: photos[index].url) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.black)
                            case .failure:
                                VStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 40))
                                    Text("Error al cargar")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(Color.black)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("Foto \(currentIndex + 1) de \(photos.count)")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
            .navigationBarItems(trailing: Button("Cerrar") { dismiss() })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
