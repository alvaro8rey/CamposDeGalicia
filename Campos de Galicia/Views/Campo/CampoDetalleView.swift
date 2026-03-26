import SwiftUI
import Supabase
import CoreLocation

/// Vista principal de detalle de un campo
struct CampoDetalleView: View {
    let campoID: UUID

    // MARK: - Environment
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State
    @State private var campo: CampoModel?
    @State private var errorMessage: String? = nil
    @State private var isVisited: Bool = false
    @State private var isCheckingLocation: Bool = false
    @State private var showingContribucionForm: Bool = false
    @State private var contribucionesAprobadas: [ContribucionAprobada] = []
    @State private var userNames: [String: String] = [:]
    @State private var showingImageViewer: Bool = false
    @State private var selectedPhotoIndex: Int = 0
    @State private var showLocationAlert = false
    @State private var locationAlertMessage = ""
    @State private var showVisitSuccessAlert = false
    @State private var visitSuccessMessage = ""

    // MARK: - Constants
    private let visitRadiusMeters: CLLocationDistance = 200
    private let maxAllowedAccuracy: CLLocationAccuracy = 100
    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    // MARK: - Computed Properties
    private var campoValue: CampoModel? {
        campo ?? camposViewModel.campo(with: campoID)
    }

    private var allPhotos: [(url: String, userId: String)] {
        contribucionesAprobadas.flatMap { contribucion in
            (contribucion.fotos_adicionales ?? []).map { url in
                (url: url, userId: contribucion.id_usuario)
            }
        }
    }

    /// Contribución principal a mostrar (la marcada como principal, o la más reciente)
    private var contribucionPrincipal: ContribucionAprobada? {
        // Primero busca la marcada como principal
        if let principal = contribucionesAprobadas.first(where: { $0.es_principal == true }) {
            return principal
        }
        // Si no hay ninguna marcada, usa la más reciente (primera del array)
        return contribucionesAprobadas.first
    }

    // MARK: - Body
    var body: some View {
        Group {
            if let campo = campo {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Hero Image
                        CampoHeroImage(
                            imageURL: (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL,
                            isVisited: isVisited,
                            isLoggedIn: supabase.auth.currentUser != nil,
                            isCheckingLocation: isCheckingLocation,
                            onToggleVisit: {
                                Task {
                                    if isVisited {
                                        await unmarkAsVisited()
                                    } else {
                                        await markVisitWithProximityCheck()
                                    }
                                }
                            }
                        )

                        // Card de información principal
                        CampoInfoCard(
                            campo: campo,
                            isLoggedIn: supabase.auth.currentUser != nil,
                            isVisited: isVisited,
                            onContribute: { showingContribucionForm = true }
                        )
                        .padding(.top, -30) // Overlap con la imagen hero

                        // Location Section
                        CampoLocationSection(campo: campo)

                        // Details Section
                        CampoDetailsSection(
                            campo: campo,
                            contribucionAprobada: contribucionPrincipal
                        )

                        // Photos Section
                        if !allPhotos.isEmpty {
                            CampoPhotosSection(
                                photos: allPhotos,
                                userNames: userNames,
                                onPhotoTap: { index in
                                    selectedPhotoIndex = index
                                    showingImageViewer = true
                                }
                            )
                        }

                        // Error Message
                        if let errorMessage = errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    withAnimation {
                                        self.errorMessage = nil
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Reviews Section
                        ReviewsSectionView(
                            campoId: campoID,
                            campoNombre: campo.nombre
                        )
                        .environmentObject(authViewModel)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                }
                .background(Color(UIColor.systemBackground))
            } else {
                LoadingView(message: L(.campoLoading), style: .shimmer)
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
        .navigationTitle(campo?.nombre ?? L(.campoDefaultName))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContribucionForm) {
            if let campo = campoValue {
                ContribucionFormView(campo: campo, onSubmit: { contribucion in
                    Task { await submitContribucion(contribucion) }
                })
            }
        }
        .sheet(isPresented: $showingImageViewer) {
            if !allPhotos.isEmpty {
                ImageGalleryViewer(photos: allPhotos, initialIndex: selectedPhotoIndex)
            }
        }
        .onAppear {
            syncCampo()
            Task {
                if let extras = await camposViewModel.extras(for: campoID) {
                    contribucionesAprobadas = extras.contribuciones
                    await preloadUserNames(for: extras.contribuciones)
                }
                await checkIfVisited()
                await fetchContribucionesAprobadas(forceRefresh: false)
            }

            // 📊 Analytics: Track campo view
            if let campo = campo {
                AnalyticsManager.shared.trackCampoView(id: campo.id, name: campo.nombre)
            }
        }
        .onChange(of: camposViewModel.campos) { oldCampos, newCampos in
            syncCampo()
        }
        .alert(isPresented: $showLocationAlert) {
            Alert(
                title: Text(L(.campoVisitErrorTitle)),
                message: Text(locationAlertMessage),
                dismissButton: .default(Text(L(.ok)))
            )
        }
        .alert(isPresented: $showVisitSuccessAlert) {
            Alert(
                title: Text(L(.campoVisitSuccessTitle)),
                message: Text(visitSuccessMessage),
                dismissButton: .default(Text(L(.ok))) {
                    errorMessage = nil
                }
            )
        }
    }

    // MARK: - Helper Methods
    private func syncCampo() {
        campo = camposViewModel.campo(with: campoID)
    }

    // MARK: - Visit Methods
    private func markVisitWithProximityCheck() async {
        // Activar loading inmediatamente
        await MainActor.run {
            isCheckingLocation = true
        }

        // Defer para asegurar que siempre se desactiva el loading
        defer {
            Task { @MainActor in
                isCheckingLocation = false
            }
        }

        guard let campo = campoValue, let lat = campo.latitud, let lon = campo.longitud else {
            await MainActor.run {
                ToastManager.shared.error(L(.campoNoCoordinates))
            }
            return
        }

        // Verificar el estado de los permisos ANTES de solicitar ubicación
        let authStatus = CLLocationManager().authorizationStatus

        guard let userLoc = await LocationService.shared.requestCurrentLocation() else {
            await MainActor.run {
                // Mensaje específico según el estado de permisos
                switch authStatus {
                case .denied, .restricted:
                    ToastManager.shared.error(L(.campoLocationDenied))
                case .notDetermined:
                    ToastManager.shared.error(L(.campoLocationNeeded))
                default:
                    ToastManager.shared.error(L(.campoLocationError))
                }
            }
            return
        }

        if userLoc.horizontalAccuracy < 0 || userLoc.horizontalAccuracy > maxAllowedAccuracy {
            await MainActor.run {
                ToastManager.shared.warning(L(.campoGPSWeak, Int(userLoc.horizontalAccuracy)))
            }
            return
        }

        let fieldLoc = CLLocation(latitude: lat, longitude: lon)
        let distance = userLoc.distance(from: fieldLoc)

        if distance <= visitRadiusMeters {
            await markAsVisited()
        } else {
            let pretty = formatDistance(distance)
            let radiusPretty = formatDistance(visitRadiusMeters)
            await MainActor.run {
                ToastManager.shared.warning(L(.campoTooFar, pretty, radiusPretty))
            }
        }
    }

    private func checkIfVisited() async {
        guard let currentUser = supabase.auth.currentUser,
              let campo = campoValue else { return }

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
            Logger.debug("Error checking visit: \(error.localizedDescription)")
        }
    }

    private func markAsVisited() async {
        guard let currentUser = supabase.auth.currentUser,
              let campo = campoValue else { return }

        do {
            let visita: [String: String] = [
                "id_usuario": currentUser.id.uuidString,
                "id_campo": campo.id.uuidString
            ]
            _ = try await supabase.from("visitas").insert(visita).execute()
            await MainActor.run {
                isVisited = true
                ToastManager.shared.success(L(.toastVisited, campo.nombre))
                // Cancelar temporizador de auto check-in si estaba pendiente
                geofenceManager.cancelPendingDwell(for: campo.id)

                // 📊 Analytics: Track campo visit
                AnalyticsManager.shared.trackCampoVisit(id: campo.id, name: campo.nombre, autoCheckin: false)
            }
            NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
        } catch {
            await MainActor.run {
                ToastManager.shared.error(L(.campoVisitError))
            }
            Logger.error("Error: \(error.localizedDescription)")
        }
    }

    private func unmarkAsVisited() async {
        // Activar loading inmediatamente
        await MainActor.run {
            isCheckingLocation = true
        }

        // Defer para asegurar que siempre se desactiva el loading
        defer {
            Task { @MainActor in
                isCheckingLocation = false
            }
        }

        guard let currentUser = supabase.auth.currentUser,
              let campo = campoValue else { return }

        do {
            _ = try await supabase.from("visitas")
                .delete()
                .eq("id_usuario", value: currentUser.id.uuidString)
                .eq("id_campo", value: campo.id.uuidString)
                .execute()
            await MainActor.run {
                isVisited = false
                ToastManager.shared.info(L(.campoUnvisitSuccess))
            }
            NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
        } catch {
            await MainActor.run {
                ToastManager.shared.error(L(.campoUnvisitError))
            }
            Logger.error("Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Contribution Methods
    private func fetchContribucionesAprobadas(forceRefresh: Bool) async {
        do {
            let extras = try await camposViewModel.loadExtras(for: campoID, forceRefresh: forceRefresh)
            contribucionesAprobadas = extras.contribuciones
            await preloadUserNames(for: extras.contribuciones)
        } catch {
            Logger.debug("Error fetching contribuciones: \(error.localizedDescription)")
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
            for id in uniqueUserIds where userNames[id] == nil {
                userNames[id] = L(.campoUnknownUser)
            }
        } catch {
            Logger.debug("Error loading user names: \(error.localizedDescription)")
            for id in uniqueUserIds {
                userNames[id] = L(.campoUnknownUser)
            }
        }
    }

    private func submitContribucion(_ contribucion: CampoContribucion) async {
        do {
            _ = try await supabase.from("campo_contribuciones").insert(contribucion).execute()
            await MainActor.run {
                showingContribucionForm = false
                ToastManager.shared.success(L(.contribucionSuccess))
            }
            await camposViewModel.invalidateExtras(for: campoID)
            await fetchContribucionesAprobadas(forceRefresh: true)
        } catch {
            await MainActor.run {
                ToastManager.shared.error(L(.contribucionError))
            }
            Logger.error("Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Utility Methods
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            return km >= 10 ? String(format: "%.0f km", km) : String(format: "%.1f km", km)
        } else {
            return "\(Int(meters.rounded())) m"
        }
    }
}
