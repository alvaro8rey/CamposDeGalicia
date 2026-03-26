import SwiftUI
import CoreLocation

/// Vista de la sección de ubicación del campo con diseño mejorado y funcionalidad desplegable
struct CampoLocationSection: View {
    let campo: CampoModel
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header con icono mejorado - CLICKEABLE
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }) {
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

                        Text(L(.campoLocation))
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
                }
                .buttonStyle(.plain)

                Spacer()

                // Botón pequeño de "Cómo llegar" cuando está plegado - a la izquierda del chevron
                if !isExpanded, let lat = campo.latitud, let lon = campo.longitud {
                    Button(action: {
                        openDirections(latitude: lat, longitude: lon)
                    }) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Icono de expansión
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .buttonStyle(.plain)
            }

            // Detalles de ubicación (solo visible cuando está expandido)
            if isExpanded {
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
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))

                // Botón grande de direcciones (solo visible cuando está expandido)
                if let lat = campo.latitud, let lon = campo.longitud {
                    VStack(spacing: 12) {
                        // Botón "Cómo llegar" (abre Maps externo)
                        Button(action: {
                            openDirections(latitude: lat, longitude: lon)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "location.north.circle.fill")
                                    .font(.title3)
                                Text(L(.campoHowToGet))
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

                        // ✅ NUEVO: Botón "Ver en el mapa" (abre mapa de la app)
                        Button(action: {
                            openInAppMap()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "map.circle.fill")
                                    .font(.title3)
                                Text("Ver en el mapa")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white)
                                    .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 4)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
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

    // ✅ NUEVO: Abrir campo en el mapa de la app
    private func openInAppMap() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowCampoInMap"),
            object: nil,
            userInfo: ["campoId": campo.id.uuidString]
        )
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
