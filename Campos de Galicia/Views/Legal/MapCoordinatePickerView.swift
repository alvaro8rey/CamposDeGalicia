import SwiftUI
import MapKit
import CoreLocation

/// Sheet que permite al usuario desplazar el mapa para colocar la chincheta
/// exactamente donde está el campo. Las coordenadas son siempre el centro del mapa.
struct MapCoordinatePickerView: View {

    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationManager = SingleLocationManager()
    @State private var isSatellite: Bool = false
    @State private var position: MapCameraPosition
    @State private var currentCenter: CLLocationCoordinate2D

    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>) {
        _selectedCoordinate = selectedCoordinate
        let initial = selectedCoordinate.wrappedValue
            ?? CLLocationCoordinate2D(latitude: 42.75, longitude: -8.0)
        let span = selectedCoordinate.wrappedValue != nil
            ? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            : MKCoordinateSpan(latitudeDelta: 1.8, longitudeDelta: 1.8)
        _position = State(initialValue: .region(MKCoordinateRegion(center: initial, span: span)))
        _currentCenter = State(initialValue: initial)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Map(position: $position)
                    .mapStyle(isSatellite ? .imagery : .standard)
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .continuous) { context in
                        currentCenter = context.region.center
                    }

                // Chincheta fija en el centro de la pantalla
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .shadow(radius: 3)
                    Rectangle()
                        .frame(width: 2, height: 12)
                        .foregroundColor(.red)
                    Ellipse()
                        .frame(width: 12, height: 4)
                        .foregroundColor(.black.opacity(0.25))
                }
                .offset(y: -28)

                // Botones flotantes + coordenadas
                VStack {
                    Spacer()

                    HStack(alignment: .bottom) {
                        // Columna de botones izquierda
                        VStack(spacing: 10) {
                            // Botón satélite / estándar
                            Button(action: { isSatellite.toggle() }) {
                                Image(systemName: isSatellite ? "map.fill" : "globe.europe.africa.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 2)
                            }

                            // Botón mi ubicación
                            Button(action: centerOnUser) {
                                Image(systemName: locationManager.authorizationDenied
                                      ? "location.slash.fill"
                                      : "location.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(locationManager.authorizationDenied ? .secondary : .blue)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 2)
                            }
                            .disabled(locationManager.authorizationDenied)
                        }

                        Spacer()

                        // Coordenadas en tiempo real
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.5f, %.5f",
                                        currentCenter.latitude,
                                        currentCenter.longitude))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Seleccionar ubicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        selectedCoordinate = currentCenter
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.location) { _, location in
                guard let location else { return }
                withAnimation {
                    position = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))
                }
            }
        }
    }

    private func centerOnUser() {
        if let location = locationManager.location {
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        } else {
            locationManager.requestLocation()
        }
    }
}

// MARK: - Location Manager (uso único para este picker)

private final class SingleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var location: CLLocation? = nil
    @Published var authorizationDenied: Bool = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silencioso — el usuario simplemente no verá el punto azul
    }
}
