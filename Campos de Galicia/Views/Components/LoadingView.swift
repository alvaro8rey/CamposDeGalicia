import SwiftUI

/// Estilos de loading disponibles
enum LoadingStyle {
    case spinner        // ProgressView circular simple
    case skeleton       // Skeleton loading para listas
    case shimmer        // Efecto shimmer animado
}

/// Vista de loading unificada para toda la app
struct LoadingView: View {
    let message: String?
    let style: LoadingStyle

    init(message: String? = nil, style: LoadingStyle = .spinner) {
        self.message = message
        self.style = style
    }

    var body: some View {
        VStack(spacing: 16) {
            switch style {
            case .spinner:
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))

            case .skeleton:
                SkeletonLoadingView()

            case .shimmer:
                ShimmerLoadingView()
            }

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Skeleton loading para listas de campos
struct SkeletonLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Una fila de skeleton loading
struct SkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Imagen placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)

            // Contenido texto
            VStack(alignment: .leading, spacing: 8) {
                // Título
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 18)

                // Subtítulo
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 14)

                // Info adicional
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 12)
            }

            Spacer()
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

/// Efecto shimmer para placeholders individuales
struct ShimmerLoadingView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.gray.opacity(0.3), location: 0.0),
                            .init(color: Color.gray.opacity(0.1), location: 0.5),
                            .init(color: Color.gray.opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 200)
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .white, .white, .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: phase)
                )
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
                    ) {
                        phase = geometry.size.width * 2
                    }
                }
        }
    }
}

/// Skeleton específico para grids (vista cuadrícula)
struct SkeletonGridView: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonGridItem()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct SkeletonGridItem: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1.3, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
            }
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        LoadingView(message: "Cargando campos...", style: .spinner)
            .frame(height: 200)

        LoadingView(style: .skeleton)
            .frame(height: 400)

        LoadingView(style: .shimmer)
            .frame(height: 200)
    }
}
