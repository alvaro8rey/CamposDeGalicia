import SwiftUI
import MapKit

/// Sheet que permite al usuario desplazar el mapa para colocar la chincheta
/// exactamente donde está el campo. Las coordenadas son siempre el centro del mapa.
struct MapCoordinatePickerView: View {

    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    // Centro inicial en Galicia
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.75, longitude: -8.0),
        span: MKCoordinateSpan(latitudeDelta: 1.8, longitudeDelta: 1.8)
    )

    // Si ya había coordenadas guardadas, centrar ahí al abrir
    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>) {
        _selectedCoordinate = selectedCoordinate
        if let existing = selectedCoordinate.wrappedValue {
            _region = State(initialValue: MKCoordinateRegion(
                center: existing,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region)
                    .ignoresSafeArea(edges: .bottom)

                // Chincheta fija en el centro de la pantalla
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .shadow(radius: 3)
                    // Palo de la chincheta
                    Rectangle()
                        .frame(width: 2, height: 12)
                        .foregroundColor(.red)
                    // Sombra en el suelo
                    Ellipse()
                        .frame(width: 12, height: 4)
                        .foregroundColor(.black.opacity(0.25))
                }
                .offset(y: -28)

                // Coordenadas en tiempo real
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.5f, %.5f",
                                    region.center.latitude,
                                    region.center.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 12)
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
                        selectedCoordinate = region.center
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
