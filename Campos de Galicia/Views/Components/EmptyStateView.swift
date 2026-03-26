import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .opacity(0.6)
                .padding(.bottom, 4)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    static func noReviews(onAddReview: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "text.bubble.fill",
            title: "Sin reseñas aún",
            subtitle: "Sé el primero en dejar una reseña sobre este campo",
            actionTitle: onAddReview != nil ? "Escribir reseña" : nil,
            action: onAddReview
        )
    }

    static func noAchievements(type: AchievementType) -> EmptyStateView {
        switch type {
        case .pending:
            return EmptyStateView(
                icon: "star.fill",
                title: "No hay logros pendientes",
                subtitle: "¡Sigue visitando campos para desbloquear más logros!"
            )
        case .completed:
            return EmptyStateView(
                icon: "trophy.fill",
                title: "Aún no has completado ningún logro",
                subtitle: "Visita campos para empezar a desbloquear logros"
            )
        }
    }

    static func noNearbyCampos(onRefresh: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "map",
            title: "No hay campos cercanos",
            subtitle: "Activa tu ubicación o busca en otra zona",
            actionTitle: onRefresh != nil ? "Reintentar" : nil,
            action: onRefresh
        )
    }

    static func noSearchResults(searchTerm: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Sin resultados",
            subtitle: "No se encontraron campos para '\(searchTerm)'"
        )
    }

    static func noConnection(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "Sin conexión",
            subtitle: "Verifica tu conexión a internet e intenta de nuevo",
            actionTitle: "Reintentar",
            action: onRetry
        )
    }
}

enum AchievementType {
    case pending
    case completed
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        EmptyStateView.noReviews()
        EmptyStateView.noAchievements(type: .pending)
    }
    .padding()
}
