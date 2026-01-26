import SwiftUI

/// Vista de la sección de detalles del campo con diseño mejorado y funcionalidad desplegable
struct CampoDetailsSection: View {
    let campo: CampoModel
    let contribucionAprobada: ContribucionAprobada?
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header con icono mejorado - CLICKEABLE
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
                                    colors: [.green, .green.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)

                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Text(L(.campoDetails))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Spacer()

                    // Icono de expansión
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            }
            .buttonStyle(.plain)

            // Detalles básicos (solo visible cuando está expandido)
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    ModernDetailRow(
                        icon: "ruler.fill",
                        label: "Superficie",
                        value: campo.superficie,
                        accentColor: .green
                    )

                    Divider()
                        .background(Color.green.opacity(0.2))

                    ModernDetailRow(
                        icon: "sportscourt.fill",
                        label: "Tipo de campo",
                        value: campo.tipo,
                        accentColor: .green
                    )

                    // Detalles de contribución
                    if let contribucion = contribucionAprobada {
                        if let tieneCantina = contribucion.tiene_cantina {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "fork.knife",
                                label: "Cantina",
                                value: tieneCantina ? "Disponible" : "No disponible",
                                accentColor: .green
                            )
                        }

                        if let aforo = contribucion.aforo_grada {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "person.3.fill",
                                label: "Aforo grada",
                                value: "\(aforo) personas",
                                accentColor: .green
                            )
                        }

                        if let medidas = contribucion.medidas_campo {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "move.3d",
                                label: "Medidas",
                                value: medidas,
                                accentColor: .green
                            )
                        }

                        if let iluminacion = contribucion.tipo_iluminacion {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "lightbulb.fill",
                                label: "Iluminación",
                                value: iluminacion,
                                accentColor: .green
                            )
                        }

                        if let estadoCesped = contribucion.estado_cesped {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "leaf.fill",
                                label: "Estado césped",
                                value: estadoCesped,
                                accentColor: .green
                            )
                        }

                        if let accesibilidad = contribucion.accesibilidad {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "figure.roll",
                                label: "Accesibilidad",
                                value: accesibilidad,
                                accentColor: .green
                            )
                        }

                        if let notas = contribucion.notas {
                            Divider()
                                .background(Color.green.opacity(0.2))

                            ModernDetailRow(
                                icon: "note.text",
                                label: "Notas",
                                value: notas,
                                accentColor: .green
                            )
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.green.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Fondo con glassmorphism
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)

                // Gradiente sutil verde
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.08),
                                Color.mint.opacity(0.05)
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
                            Color.green.opacity(0.3),
                            Color.green.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.green.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
    }
}

/// Helper para mostrar una fila opcional (mantenida por compatibilidad)
struct OptionalDetailRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value = value {
            DetailRow(label: label, value: value)
        }
    }
}
