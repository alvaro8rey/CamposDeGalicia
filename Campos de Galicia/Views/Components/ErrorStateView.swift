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
        VStack(spacing: 16) {
            // Icono de error
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }

            // Mensaje de error
            VStack(spacing: 8) {
                Text("Algo salió mal")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Indicador de reintentos si hay
            if retryCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text("Intento \(retryCount) de \(maxRetries)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
            }

            // Botones
            VStack(spacing: 10) {
                if retryCount < maxRetries {
                    // Botón reintentar
                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reintentar")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                } else if let onSupport = onSupport {
                    // Máximo de reintentos alcanzado - mostrar soporte
                    VStack(spacing: 10) {
                        Text("El problema persiste")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: onSupport) {
                            HStack(spacing: 8) {
                                Image(systemName: "questionmark.circle")
                                Text("Contactar soporte")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            colorScheme == .dark
                ? Color(UIColor.secondarySystemBackground)
                : Color(UIColor.systemBackground)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
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
