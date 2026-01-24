import SwiftUI
import CoreLocation

/// Vista de la sección de ubicación del campo con diseño mejorado
struct CampoLocationSection: View {
    let campo: CampoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header con icono mejorado
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Text("Ubicación")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Detalles de ubicación
            VStack(alignment: .leading, spacing: 14) {
                ModernDetailRow(
                    icon: "house.fill",
                    label: "Localidad",
                    value: campo.localidad,
                    accentColor: .blue
                )

                Divider()
                    .background(Color.blue.opacity(0.2))

                ModernDetailRow(
                    icon: "map.fill",
                    label: "Provincia",
                    value: campo.provincia,
                    accentColor: .blue
                )

                Divider()
                    .background(Color.blue.opacity(0.2))

                ModernDetailRow(
                    icon: "signpost.right.fill",
                    label: "Dirección",
                    value: campo.direccion,
                    accentColor: .blue
                )

                Divider()
                    .background(Color.blue.opacity(0.2))

                ModernDetailRow(
                    icon: "envelope.fill",
                    label: "Código Postal",
                    value: campo.codigo_postal,
                    accentColor: .blue
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(0.05))
            )

            // Botón de direcciones
            if let lat = campo.latitud, let lon = campo.longitud {
                Button(action: {
                    openDirections(latitude: lat, longitude: lon)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.title3)
                        Text("Cómo llegar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Fondo con glassmorphism
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)

                // Gradiente sutil azul
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.08),
                                Color.cyan.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.blue.opacity(0.15), radius: 20, x: 0, y: 10)
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

/// Helper para mostrar una fila de detalle (versión original, mantenida por compatibilidad)
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

/// Fila de detalle moderna con icono
struct ModernDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icono
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(accentColor)
            }

            // Contenido
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}
