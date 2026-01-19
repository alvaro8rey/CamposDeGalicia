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

    // Parámetros de validación de visita por proximidad
    private let visitRadiusMeters: CLLocationDistance = 500 // radio permitido
    private let maxAllowedAccuracy: CLLocationAccuracy = 100 // precisión mínima aceptable (menor es mejor)

    // URL de la imagen predeterminada de Supabase
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
                ZStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Hero Image
                        ZStack(alignment: .bottomLeading) {
                            let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                            if let url = URL(string: imageURL) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                        .clipped()
                                } placeholder: {
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        ProgressView()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
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
                                    HStack(spacing: 4) {
                                        Image(systemName: isVisited ? "checkmark.circle.fill" : "mappin.circle.fill")
                                            .font(.caption)
                                        Text(isVisited ? "Visitado" : "Marcar visita")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        (isVisited ? Color.green : Color.blue)
                                            .opacity(0.9)
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.2), radius: 4)
                                }
                                .padding(12)
                            }
                        }

                        // Header Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(campo.nombre)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                // Visit button if authenticated
                                if supabase.auth.currentUser != nil {
                                    Button(action: {
                                        showingContribucionForm = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle")
                                                .font(.caption)
                                            Text("Contribuir")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // UBICACIÓN
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text("Ubicación")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Text("Localidad:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(campo.localidad)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    HStack(alignment: .top) {
                                        Text("Provincia:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(campo.provincia)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    HStack(alignment: .top) {
                                        Text("Dirección:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(campo.direccion)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    HStack(alignment: .top) {
                                        Text("Código Postal:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(campo.codigo_postal)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                Spacer()

                                if let lat = campo.latitud, let lon = campo.longitud {
                                    Button(action: {
                                        // Intentar abrir en la app de Google Maps con ruta desde ubicación actual
                                        let googleMapsURL = URL(string: "comgooglemaps://?saddr=&daddr=\(lat),\(lon)&directionsmode=driving")
                                        if let url = googleMapsURL, UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url)
                                        } else {
                                            // Si no está instalada, abrir en Safari con Google Maps web
                                            let webUrlString = "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=driving"
                                            if let webUrl = URL(string: webUrlString) {
                                                UIApplication.shared.open(webUrl)
                                            }
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "map.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                            Text("Ruta")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 60, height: 60)
                                        .background(
                                            LinearGradient(
                                                colors: [.blue, .blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(16)
                                        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                                    }
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.gray)
                                        Text("Ruta")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 60, height: 60)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)

                        // DETALLES DEL CAMPO
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text("Detalles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            HStack(alignment: .top) {
                                Text("Superficie:")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text(campo.superficie)
                                    .foregroundColor(.secondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(alignment: .top) {
                                Text("Tipo de campo:")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text(campo.tipo)
                                    .foregroundColor(.secondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let contribucion = contribucionesAprobadas.first {
                                if let tieneCantina = contribucion.tiene_cantina {
                                    HStack(alignment: .top) {
                                        Text("Tiene cantina:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(tieneCantina ? "Sí" : "No")
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if let aforoGrada = contribucion.aforo_grada {
                                    HStack(alignment: .top) {
                                        Text("Aforo de la grada:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text("\(aforoGrada)")
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if let medidasCampo = contribucion.medidas_campo {
                                    HStack(alignment: .top) {
                                        Text("Medidas del campo:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(medidasCampo)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if let tipoIluminacion = contribucion.tipo_iluminacion {
                                    HStack(alignment: .top) {
                                        Text("Tipo de iluminación:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(tipoIluminacion)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if let estadoCesped = contribucion.estado_cesped {
                                    HStack(alignment: .top) {
                                        Text("Estado del césped:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(estadoCesped)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if let accesibilidad = contribucion.accesibilidad {
                                    HStack(alignment: .top) {
                                        Text("Accesibilidad:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(accesibilidad)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if let notas = contribucion.notas {
                                    HStack(alignment: .top) {
                                        Text("Notas adicionales:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(notas)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)

                        if !contribucionesAprobadas.isEmpty {
                            let todasLasFotos: [(url: String, userId: String)] = contribucionesAprobadas.flatMap { contribucion in
                                (contribucion.fotos_adicionales ?? []).map { url in
                                    (url: url, userId: contribucion.id_usuario)
                                }
                            }

                            if !todasLasFotos.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "photo.stack.fill")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                        Text("Fotos")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(todasLasFotos.indices, id: \.self) { index in
                                                let foto = todasLasFotos[index]
                                                let nombre = userNames[foto.userId] ?? "Usuario desconocido"

                                                VStack(spacing: 8) {
                                                    if let url = URL(string: foto.url) {
                                                        CachedAsyncImage(url: url) { image in
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 120, height: 120)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                                                        } placeholder: {
                                                            ZStack {
                                                                Color.gray.opacity(0.2)
                                                                ProgressView()
                                                            }
                                                            .frame(width: 120, height: 120)
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
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        // RESEÑAS SECTION
                        ReviewsSectionView(
                            campoId: campoID,
                            campoNombre: campo.nombre
                        )
                        .environmentObject(authViewModel)
                        .padding(.top, 8)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: min(geometry.size.width, 600), alignment: .center)
                }
                .background(Color(UIColor.systemBackground))
            }
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView("Cargando campo...")
                    Text("No se encontró la información del campo.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
    }

    // MARK: - Proximidad y visitas

    private func markVisitWithProximityCheck() async {
        // 1) Coordenadas del campo
        guard let campo = campoValue, let lat = campo.latitud, let lon = campo.longitud else {
            locationAlertMessage = "Este campo no tiene coordenadas válidas."
            showLocationAlert = true
            return
        }

        // 2) Ubicación actual
        guard let userLoc = await LocationService.shared.requestCurrentLocation() else {
            locationAlertMessage = "No pudimos obtener tu ubicación. Activa los permisos de localización."
            showLocationAlert = true
            return
        }

        // 3) Valida precisión
        if userLoc.horizontalAccuracy < 0 || userLoc.horizontalAccuracy > maxAllowedAccuracy {
            locationAlertMessage = "La señal de GPS es poco precisa ahora mismo. Inténtalo de nuevo al aire libre."
            showLocationAlert = true
            return
        }

        // 4) Calcula distancia
        let fieldLoc = CLLocation(latitude: lat, longitude: lon)
        let distance = userLoc.distance(from: fieldLoc) // en metros

        if distance <= visitRadiusMeters {
            // ✅ Dentro del radio: registra visita como haces ahora
            await markAsVisited()
        } else {
            // ❌ Demasiado lejos
            let pretty = formatDistance(distance)
            let radiusPretty = formatDistance(visitRadiusMeters)
            locationAlertMessage = "Estás a ~\(pretty) del campo. Acércate (≤ \(radiusPretty)) para marcar la visita."
            showLocationAlert = true
        }
    }

    // Resto del código (métodos auxiliares)
    private func getAllPhotos() -> [(url: String, userId: String)]? {
        let todasLasFotos: [(url: String, userId: String)] = contribucionesAprobadas.flatMap { contribucion in
            (contribucion.fotos_adicionales ?? []).map { url in
                (url: url, userId: contribucion.id_usuario)
            }
        }
        return todasLasFotos.isEmpty ? nil : todasLasFotos
    }

    private func checkIfVisited() async {
        guard let currentUser = supabase.auth.currentUser else {
            print("Usuario no autenticado al verificar visita")
            return
        }

        guard let campo = campoValue else {
            return
        }

        do {
            let response = try await supabase.from("visitas")
                .select("id_campo")
                .eq("id_usuario", value: currentUser.id.uuidString)
                .eq("id_campo", value: campo.id.uuidString)
                .execute()
            let data = response.data
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let array = jsonObject as? [[String: Any]], !array.isEmpty {
                isVisited = true
            } else {
                isVisited = false
            }
            print("Estado de visita para \(campo.nombre): \(isVisited)")
        } catch {
            errorMessage = "Error al verificar visita: \(error.localizedDescription)"
            print("Error al verificar visita: \(error)")
        }
    }

    private func markAsVisited() async {
        guard let currentUser = supabase.auth.currentUser else {
            errorMessage = "Usuario no autenticado"
            return
        }

        guard let campo = campoValue else {
            return
        }

        do {
            let visita: [String: String] = [
                "id_usuario": currentUser.id.uuidString,
                "id_campo": campo.id.uuidString
            ]
            let response = try await supabase.from("visitas")
                .insert(visita)
                .execute()
            isVisited = true
            errorMessage = "Campo marcado como visitado con éxito."
            NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
            print("Visita registrada para campo: \(campo.nombre), respuesta: \(response)")
        } catch {
            errorMessage = "Error al registrar visita: \(error.localizedDescription)"
            print("Error al registrar visita: \(error)")
        }
    }

    private func unmarkAsVisited() async {
        guard let currentUser = supabase.auth.currentUser else {
            errorMessage = "Usuario no autenticado"
            return
        }

        guard let campo = campoValue else {
            return
        }

        do {
            let response = try await supabase.from("visitas")
                .delete()
                .eq("id_usuario", value: currentUser.id.uuidString)
                .eq("id_campo", value: campo.id.uuidString)
                .execute()
            isVisited = false
            errorMessage = "Visita desmarcada con éxito."
            NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
            print("Visita eliminada para campo: \(campo.nombre), respuesta: \(response)")
        } catch {
            errorMessage = "Error al desmarcar visita: \(error.localizedDescription)"
            print("Error al desmarcar visita: \(error)")
        }
    }

    private func fetchContribucionesAprobadas(forceRefresh: Bool) async {
        do {
            let extras = try await camposViewModel.loadExtras(for: campoID, forceRefresh: forceRefresh)
            contribucionesAprobadas = extras.contribuciones
            errorMessage = nil

            await preloadUserNames(for: extras.contribuciones)
        } catch {
            errorMessage = "Error al cargar contribuciones aprobadas: \(error.localizedDescription)"
            print("Error al cargar contribuciones aprobadas: \(error)")
        }
    }

    private func preloadUserNames(for contribuciones: [ContribucionAprobada]) async {
        // Optimización: Obtener IDs únicos de usuarios
        let uniqueUserIds = Array(Set(contribuciones.map { $0.id_usuario }))

        guard !uniqueUserIds.isEmpty else { return }

        Logger.debug("🔍 Cargando \(uniqueUserIds.count) nombres de usuario en batch")

        do {
            // ✅ BATCH QUERY: Una sola petición para todos los usuarios
            let response = try await supabase.from("perfiles")
                .select("id, nombre")
                .in("id", values: uniqueUserIds)
                .execute()

            let decoder = JSONDecoder()
            let profiles = try decoder.decode([UserProfile].self, from: response.data)

            // Mapear resultados al diccionario
            for profile in profiles {
                if let id = profile.id {
                    userNames[id] = profile.nombre
                }
            }

            // Marcar usuarios no encontrados
            for userId in uniqueUserIds {
                if userNames[userId] == nil {
                    userNames[userId] = "Usuario desconocido"
                }
            }

            Logger.success("✅ Nombres cargados: \(profiles.count)/\(uniqueUserIds.count)")
        } catch {
            Logger.error("❌ Error cargando nombres de usuario: \(error.localizedDescription)")
            // Fallback: marcar todos como desconocidos
            for userId in uniqueUserIds {
                userNames[userId] = "Usuario desconocido"
            }
        }
    }

    private func submitContribucion(_ contribucion: CampoContribucion) async {

        guard let campo = campoValue else {
            return
        }
        do {
            let response = try await supabase.from("campo_contribuciones")
                .insert(contribucion)
                .execute()
            errorMessage = "Contribución enviada con éxito. ¡Gracias por tu ayuda!"
            print("Contribución enviada para campo: \(campo.nombre), respuesta: \(response)")
            showingContribucionForm = false
            camposViewModel.invalidateExtras(for: campoID)
            await fetchContribucionesAprobadas(forceRefresh: true)
        } catch {
            errorMessage = "Error al enviar la contribución: \(error.localizedDescription)"
            print("Error al enviar contribución: \(error)")
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            // 0 decimales si >= 10 km, 1 decimal si < 10 km
            return km >= 10 ? String(format: "%.0f km", km) : String(format: "%.1f km", km)
        } else {
            return "\(Int(meters.rounded())) m"
        }
    }

}

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
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        Task {
                            await submitForm()
                        }
                    }
                    .disabled(!isFormValid())
                }
            }
        }
    }

    private func isFormValid() -> Bool {
        return !selectedPhotos.isEmpty ||
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
                    let image = Image(uiImage: uiImage)
                    photoPreviews.append(image)
                }
            } catch {
                print("⚠️ Error al cargar previsualización de foto: \(error.localizedDescription)")
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
        for (index, photoItem) in selectedPhotos.enumerated() {
            let data: Data
            do {
                guard let loadedData = try await photoItem.loadTransferable(type: Data.self) else {
                    print("⚠️ Error: No se pudo cargar la foto #\(index)")
                    continue
                }
                data = loadedData
            } catch {
                print("⚠️ Error al cargar foto #\(index): \(error.localizedDescription)")
                continue
            }

            let fileName = "\(campo.id.uuidString)-\(UUID().uuidString)-photo-\(index).jpg"
            let filePath = "fotos-campos/\(fileName)"

            let _ = try await supabase.storage
                .from("fotos-campos")
                .upload(
                    path: fileName,
                    file: data
                )

            let publicURL = try supabase.storage
                .from("fotos-campos")
                .getPublicURL(path: fileName)
                .absoluteString

            uploadedURLs.append(publicURL)
        }

        return uploadedURLs.isEmpty ? nil : uploadedURLs
    }

    private func submitForm() async {
        guard let currentUser = supabase.auth.currentUser else {
            print("Usuario no autenticado al enviar contribución")
            return
        }

        do {
            let fotosURLs = try await uploadPhotos()

            let aforo = Int(aforoGrada)

            let contribucion = CampoContribucion(
                id_usuario: currentUser.id.uuidString,
                id_campo: campo.id.uuidString,
                fotos_adicionales: fotosURLs,
                tiene_cantina: tieneCantina ? true : nil,
                aforo_grada: aforo,
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
            print("Error al subir fotos o enviar contribución: \(error)")
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
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black)
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
                                .background(Color.black)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()
            .overlay(
                VStack {
                    Spacer()
                    Text("Foto \(currentIndex + 1) de \(photos.count)")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.bottom, 50)
                }
            )
            .navigationBarItems(trailing: Button("Cerrar") {
                dismiss()
            })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
