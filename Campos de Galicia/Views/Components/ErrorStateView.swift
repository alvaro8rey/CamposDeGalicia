import SwiftUI

// MARK: - Error State View

struct ErrorStateView: View {
    @Environment(\.colorScheme) var colorScheme

    let message: String
    let retryCount: Int
    let maxRetries: Int
    let onRetry: () -> Void
    let onSupport: (() -> Void)?

    init(
        message: String,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        onRetry: @escaping () -> Void,
        onSupport: (() -> Void)? = nil
    ) {
        self.message = message
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.onRetry = onRetry
        self.onSupport = onSupport
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Icono de error
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(Opacity.medium))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.xxl))
                    .foregroundColor(.orange)
            }

            // Mensaje de error
            VStack(spacing: Spacing.sm) {
                Text("Algo salió mal")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.sm)
            }

            // Indicador de reintentos si hay
            if retryCount > 0 {
                HStack(spacing: Spacing.xs + 2) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text("Intento \(retryCount) de \(maxRetries)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs + 2)
                .background(Color.gray.opacity(Opacity.medium))
                .cornerRadius(CornerRadius.sm)
            }

            // Botones
            VStack(spacing: Spacing.sm + 2) {
                if retryCount < maxRetries {
                    // Botón reintentar
                    Button(action: onRetry) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reintentar")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(Opacity.strong)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(CornerRadius.md)
                    }
                } else if let onSupport = onSupport {
                    // Máximo de reintentos alcanzado - mostrar soporte
                    VStack(spacing: Spacing.sm + 2) {
                        Text("El problema persiste")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: onSupport) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "questionmark.circle")
                                Text("Contactar soporte")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.blue.opacity(Opacity.light))
                            .cornerRadius(CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.blue.opacity(Opacity.strong), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.vertical, Spacing.xxxl)
        .padding(.horizontal, Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            colorScheme == .dark
                ? Color(UIColor.secondarySystemBackground)
                : Color(UIColor.systemBackground)
        )
        .cornerRadius(CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.orange.opacity(Opacity.border), lineWidth: 1)
        )
        .shadowMedium()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ErrorStateView(
            message: "No se pudo cargar las reseñas. Verifica tu conexión.",
            retryCount: 0,
            onRetry: {}
        )

        ErrorStateView(
            message: "Error de conexión persistente.",
            retryCount: 3,
            onRetry: {},
            onSupport: {}
        )
    }
    .padding()
}
