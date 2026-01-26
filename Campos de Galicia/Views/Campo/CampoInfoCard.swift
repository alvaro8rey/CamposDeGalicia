import SwiftUI

/// Card de información principal del campo con diseño moderno
struct CampoInfoCard: View {
    let campo: CampoModel
    let isLoggedIn: Bool
    let onContribute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Nombre del campo
            Text(campo.nombre)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Subtítulo con ubicación
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(campo.localidad), \(campo.provincia)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Badges informativos
            HStack(spacing: 10) {
                // Badge tipo de campo
                InfoBadge(
                    icon: "sportscourt.fill",
                    text: campo.tipo,
                    color: .blue
                )

                // Badge superficie
                InfoBadge(
                    icon: "ruler.fill",
                    text: campo.superficie,
                    color: .green
                )
            }

            // Botón de contribuir (solo si está logueado)
            if isLoggedIn {
                Button(action: onContribute) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text(L(.campoContribute))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Fondo con glassmorphism
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)

                // Gradiente sutil
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.05),
                                Color.green.opacity(0.05)
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
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}

/// Badge informativo con icono
struct InfoBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)

                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}
