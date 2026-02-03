import SwiftUI
import CoreLocation

// MARK: - Extensión para comparar coordenadas
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct CamposCercanosView: View {
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var isLoadingLocation: Bool
    @Binding var distanciaPredeterminada: Double
    let requestLocation: () -> Void

    @State private var nearbyCampos: [CampoWithDistance] = []
    @State private var errorMessage: String? = nil
    @State private var selectedDistance: Double
    @State private var visitedCampoIds: Set<UUID> = []

    private let distanceOptions: [Double] = [10.0, 25.0, 50.0]

    init(
        userLocation: Binding<CLLocationCoordinate2D?>,
        isLoadingLocation: Binding<Bool>,
        distanciaPredeterminada: Binding<Double>,
        requestLocation: @escaping () -> Void
    ) {
        self._userLocation = userLocation
        self._isLoadingLocation = isLoadingLocation
        self._distanciaPredeterminada = distanciaPredeterminada
        self.requestLocation = requestLocation

        let validDistance = [10.0, 25.0, 50.0]
            .min(by: { abs($0 - distanciaPredeterminada.wrappedValue) < abs($1 - distanciaPredeterminada.wrappedValue) }) ?? 10.0
        self._selectedDistance = State(initialValue: validDistance)
    }

    var body: some View {
        ZStack {
            // Fondo que se extiende por completo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // Contenido
            VStack(spacing: 12) {
                // ✅ Contenedor fijo arriba con el selector
                DistancePickerCard(selectedDistance: $selectedDistance, distanciaPredeterminada: distanciaPredeterminada)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // ✅ Scroll solo para la lista
                ScrollView {
                    VStack(spacing: 0) {
                        if isLoadingLocation {
                            LoadingView(message: L(.loadingLocation), style: .skeleton)
                        } else if let errorMessage = errorMessage {
                            EmptyCard(text: errorMessage)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        } else if let _ = userLocation {
                            if nearbyCampos.isEmpty {
                                EmptyCard(text: L(.nearbyNoFieldsFound, Int(selectedDistance)))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                            } else {
                                // Vista de lista mejorada
                                LazyVStack(spacing: 12) {
                                    ForEach(nearbyCampos, id: \.campo.id) { item in
                                        NavigationLink(destination: CampoDetalleView(campoID: item.campo.id)
                                            .environmentObject(authViewModel)) {
                                            CampoRowView_Classic(campoWithDistance: item, visitedCampoIds: visitedCampoIds)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 80)
                            }
                        } else {
                            EmptyCard(text: L(.nearbyLocationError))
                                .padding(.horizontal, 16)
                                .padding(.top, 40)
                        }
                    }
                }
                .refreshable {
                    requestLocation()
                }
            }
            .navigationTitle(L(.nearbyCamposTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L(.nearbyCamposTitle))
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .onAppear {
                updateNearbyCampos()
                if userLocation == nil { requestLocation() }
                loadVisitedCampos()
            }
            .onChange(of: userLocation) { oldLocation, newLocation in updateNearbyCampos() }
            .onChange(of: camposViewModel.campos) { oldCampos, newCampos in updateNearbyCampos() }
            .onChange(of: selectedDistance) { oldDistance, newDistance in updateNearbyCampos() }
            .onChange(of: distanciaPredeterminada) { oldDistance, newDistance in
                let validDistance = distanceOptions.min(by: { abs($0 - newDistance) < abs($1 - newDistance) }) ?? 10.0
                selectedDistance = validDistance
                updateNearbyCampos()
            }
        }
    }

    // MARK: - Cálculos
    private func updateNearbyCampos() {
        guard let userLocation = userLocation else { return }

        // Capturar valores necesarios para el background thread
        let campos = camposViewModel.campos
        let maxDistance = selectedDistance
        let userLoc = userLocation

        // Mover cálculos pesados a background thread
        Task.detached(priority: .userInitiated) {
            // Cálculos trigonométricos en background
            let camposWithDistances = campos.compactMap { campo -> CampoWithDistance? in
                guard let lat = campo.latitud, let lon = campo.longitud else { return nil }
                let dist = Self.calculateDistanceStatic(
                    from: userLoc,
                    to: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                )
                return CampoWithDistance(campo: campo, distance: dist)
            }
            .filter { $0.distance <= maxDistance }
            .sorted { $0.distance < $1.distance }

            // Actualizar UI en main thread
            await MainActor.run {
                self.nearbyCampos = camposWithDistances
            }
        }
    }

    // Versión estática para uso en Task.detached
    private static func calculateDistanceStatic(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let dφ = (to.latitude - from.latitude) * .pi / 180
        let dλ = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    // Versión de instancia (mantener por compatibilidad)
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        Self.calculateDistanceStatic(from: from, to: to)
    }

    private func loadVisitedCampos() {
        guard let userId = authViewModel.user?.id.uuidString else { return }

        Task {
            do {
                let response = try await supabase.from("visitas")
                    .select("id_campo")
                    .eq("id_usuario", value: userId)
                    .execute()

                if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                    let ids = jsonData.compactMap { dict -> UUID? in
                        guard let idString = dict["id_campo"] as? String else { return nil }
                        return UUID(uuidString: idString)
                    }
                    visitedCampoIds = Set(ids)
                }
            } catch {
                Logger.error("Error loading visited campos: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Subvistas
private struct DistancePickerCard: View {
    @Binding var selectedDistance: Double
    let distanciaPredeterminada: Double
    private let distanceOptions: [Double] = [10.0, 25.0, 50.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(L(.nearbyMaxDistance))
                    .font(.headline)
                Spacer()
            }
            Picker(L(.nearbyMaxDistance), selection: $selectedDistance) {
                ForEach(distanceOptions, id: \.self) { distance in
                    Text("\(Int(distance)) km").tag(distance)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .onAppear {
            if !distanceOptions.contains(selectedDistance) {
                selectedDistance = distanceOptions.min(by: { abs($0 - distanciaPredeterminada) < abs($1 - distanciaPredeterminada) }) ?? 10.0
            }
        }
    }
}

private struct EmptyCard: View {
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .opacity(0.5)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// Card rediseñada con mejor UX
private struct CampoRowView_Classic: View {
    let campoWithDistance: CampoWithDistance
    let visitedCampoIds: Set<UUID>
    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    var body: some View {
        HStack(spacing: 14) {
            let imageURL = (campoWithDistance.campo.foto_url?.isEmpty == false ? campoWithDistance.campo.foto_url : nil) ?? defaultImageURL
            if let url = URL(string: imageURL) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 120, height: 120)
                    ) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .cornerRadius(12)
                            .clipped()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                            .frame(width: 70, height: 70)
                            .cornerRadius(12)
                    }

                    // Indicador de campo visitado
                    if visitedCampoIds.contains(campoWithDistance.campo.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 16, height: 16)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(campoWithDistance.campo.nombre)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(campoWithDistance.campo.localidad ?? ""), \(campoWithDistance.campo.provincia)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(L(.nearbyDistance, campoWithDistance.distance))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Modelo auxiliar
struct CampoWithDistance {
    let campo: CampoModel
    let distance: Double
}
