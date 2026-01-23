import SwiftUI
import CoreLocation

/// Vista de la sección de ubicación del campo
struct CampoLocationSection: View {
    let campo: CampoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Ubicación")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                DetailRow(label: "Localidad:", value: campo.localidad)
                DetailRow(label: "Provincia:", value: campo.provincia)
                DetailRow(label: "Dirección:", value: campo.direccion)
                DetailRow(label: "Código Postal:", value: campo.codigo_postal)
            }

            if let lat = campo.latitud, let lon = campo.longitud {
                Button(action: {
                    openDirections(latitude: lat, longitude: lon)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func openDirections(latitude: Double, longitude: Double) {
        let googleMapsURL = URL(string: "comgooglemaps://?saddr=&daddr=\(latitude),\(longitude)&directionsmode=driving")
        if let url = googleMapsURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let webUrlString = "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=driving"
            if let webUrl = URL(string: webUrlString) {
                UIApplication.shared.open(webUrl)
            }
        }
    }
}

/// Helper para mostrar una fila de detalle
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
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
}
