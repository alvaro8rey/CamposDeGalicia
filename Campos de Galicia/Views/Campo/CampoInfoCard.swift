import SwiftUI

/// Card de información principal del campo con diseño moderno
struct CampoInfoCard: View {
    let campo: CampoModel
    let isLoggedIn: Bool
    let isVisited: Bool
    let onContribute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Nombre del campo
            Text(campo.nombre)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(Opacity.strong)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Subtítulo con ubicación
            HStack(spacing: Spacing.xs + 2) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(campo.localidad), \(campo.provincia)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Badges informativos
            HStack(spacing: Spacing.sm + 2) {
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

            // Botón de contribuir (solo si está logueado y ha visitado el campo)
            if isLoggedIn && isVisited {
                Button(action: onContribute) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text(L(.campoContribute))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(Opacity.strong)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md + 2))
                    .shadow(color: .blue.opacity(Opacity.strong), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Fondo con glassmorphism
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(.ultraThinMaterial)

                // Gradiente sutil
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(Opacity.subtle),
                                Color.green.opacity(Opacity.subtle)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(Opacity.strong),
                            Color.white.opacity(Opacity.light)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadowLarge()
        .paddingHorizontal()
    }
}

/// Badge informativo con icono
struct InfoBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs + 1) {
            ZStack {
                Circle()
                    .fill(color.opacity(Opacity.medium))
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
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.xs + 2)
        .background(
            Capsule()
                .fill(color.opacity(Opacity.light - 0.02))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(Opacity.border), lineWidth: 1)
        )
    }
}
