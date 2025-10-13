import SwiftUI
import CoreLocation

// MARK: - Extensión para comparar coordenadas
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct CamposCercanosView: View {
    @Binding var campos: [CampoModel]
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var isLoadingLocation: Bool
    @Binding var distanciaPredeterminada: Double
    let requestLocation: () -> Void

    @State private var nearbyCampos: [CampoWithDistance] = []
    @State private var errorMessage: String? = nil
    @State private var selectedDistance: Double

    private let distanceOptions: [Double] = [10.0, 25.0, 50.0]

    init(
        campos: Binding<[CampoModel]>,
        userLocation: Binding<CLLocationCoordinate2D?>,
        isLoadingLocation: Binding<Bool>,
        distanciaPredeterminada: Binding<Double>,
        requestLocation: @escaping () -> Void
    ) {
        self._campos = campos
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
            VStack(spacing: 12) {
                // ✅ Contenedor fijo arriba con el selector
                DistancePickerCard(selectedDistance: $selectedDistance, distanciaPredeterminada: distanciaPredeterminada)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // ✅ Scroll solo para la lista
                ScrollView {
                    VStack(spacing: 0) {
                        if isLoadingLocation {
                            ProgressView("Obteniendo ubicación...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .padding(.top, 40)
                        } else if let errorMessage = errorMessage {
                            EmptyCard(text: errorMessage)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        } else if let _ = userLocation {
                            if nearbyCampos.isEmpty {
                                EmptyCard(text: "No se encontraron campos cercanos dentro de \(Int(selectedDistance)) km.")
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                            } else {
                                // ✅ Misma estructura que en ContentView
                                LazyVStack(spacing: 0) {
                                    ForEach(nearbyCampos, id: \.campo.id) { item in
                                        NavigationLink(destination: CampoDetalleView(campo: item.campo)) {
                                            CampoRowView_Classic(campoWithDistance: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.top, 8)
                            }
                        } else {
                            EmptyCard(text: "No se pudo obtener la ubicación. Habilita los servicios de ubicación.")
                                .padding(.horizontal, 16)
                                .padding(.top, 40)
                        }
                    }
                }
            }
            .navigationTitle("Campos cercanos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Campos cercanos")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.15), Color(UIColor.systemBackground).opacity(0.9)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .onAppear {
                updateNearbyCampos()
                if userLocation == nil { requestLocation() }
            }
            .onChange(of: userLocation) { _ in updateNearbyCampos() }
            .onChange(of: campos) { _ in updateNearbyCampos() }
            .onChange(of: selectedDistance) { _ in updateNearbyCampos() }
            .onChange(of: distanciaPredeterminada) { newDistance in
                let validDistance = distanceOptions.min(by: { abs($0 - newDistance) < abs($1 - newDistance) }) ?? 10.0
                selectedDistance = validDistance
                updateNearbyCampos()
            }

            // Botón flotante para actualizar ubicación
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { requestLocation() }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Cálculos
    private func updateNearbyCampos() {
        guard let userLocation = userLocation else { return }
        nearbyCampos = campos
            .compactMap { campo -> CampoWithDistance? in
                guard let lat = campo.latitud, let lon = campo.longitud else { return nil }
                let dist = calculateDistance(
                    from: userLocation,
                    to: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                )
                return CampoWithDistance(campo: campo, distance: dist)
            }
            .filter { $0.distance <= selectedDistance }
            .sorted { $0.distance < $1.distance }
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let dφ = (to.latitude - from.latitude) * .pi / 180
        let dλ = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

// MARK: - Subvistas
private struct DistancePickerCard: View {
    @Binding var selectedDistance: Double
    let distanciaPredeterminada: Double
    private let distanceOptions: [Double] = [10.0, 25.0, 50.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distancia máxima")
                .font(.headline)
            Picker("Distancia máxima", selection: $selectedDistance) {
                ForEach(distanceOptions, id: \.self) { distance in
                    Text("\(Int(distance)) km").tag(distance)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
        Text(text)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// ✅ Misma fila que en ContentView
private struct CampoRowView_Classic: View {
    let campoWithDistance: CampoWithDistance
    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    var body: some View {
        HStack(spacing: 12) {
            let imageURL = (campoWithDistance.campo.foto_url?.isEmpty == false ? campoWithDistance.campo.foto_url! : defaultImageURL)
            if let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(10)
                        .clipped()
                } placeholder: {
                    Color.gray.opacity(0.3)
                        .frame(width: 60, height: 60)
                        .cornerRadius(10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(campoWithDistance.campo.nombre)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(campoWithDistance.campo.localidad), \(campoWithDistance.campo.provincia)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Distancia: \(String(format: "%.1f", campoWithDistance.distance)) km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        // Sin fondo, sin sombra, sin divisor → igual que ContentView
    }
}

// MARK: - Modelo auxiliar
struct CampoWithDistance {
    let campo: CampoModel
    let distance: Double
}
