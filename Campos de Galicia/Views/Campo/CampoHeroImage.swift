import SwiftUI
import CoreLocation

/// Vista del hero image con badge de visita mejorada
struct CampoHeroImage: View {
    let imageURL: String
    let isVisited: Bool
    let isLoggedIn: Bool
    let isCheckingLocation: Bool
    let onToggleVisit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background Image
                if let url = URL(string: imageURL) {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 1200, height: 800)
                    ) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: 220)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            LinearGradient(
                                colors: [Color.blue.opacity(Opacity.strong), Color.green.opacity(Opacity.strong)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            ProgressView()
                                .tint(.white)
                        }
                        .frame(width: geometry.size.width, height: 220)
                    }
                }

                // Gradiente oscuro inferior para mejor legibilidad
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(Opacity.disabled)
                    ]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 220)

                // Gradiente difuminado en la parte inferior para suavizar el corte
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color(UIColor.systemBackground).opacity(Opacity.strong),
                        Color(UIColor.systemBackground).opacity(Opacity.disabled + 0.1)
                    ]),
                    startPoint: UnitPoint(x: 0.5, y: 0.85),
                    endPoint: .bottom
                )
                .frame(height: 220)

                // Visit Badge con glassmorphism
                if isLoggedIn {
                    Button(action: {
                        HapticFeedback.medium()
                        onToggleVisit()
                    }) {
                        HStack(spacing: Spacing.xs + 2) {
                            if isCheckingLocation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: isVisited ? "checkmark.circle.fill" : "mappin.circle.fill")
                                    .font(.caption)
                                    .imageScale(.medium)
                            }

                            Text(isCheckingLocation ? "Verificando..." : (isVisited ? "Visitado" : "Marcar visita"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            ZStack {
                                // Glassmorphism effect
                                RoundedRectangle(cornerRadius: CornerRadius.xl)
                                    .fill(
                                        (isVisited ? Color.green : Color.blue)
                                            .opacity(Opacity.strong)
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                        )
                        .clipShape(Capsule())
                        .shadowMedium()
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(Opacity.border), lineWidth: 1)
                        )
                    }
                    .disabled(isCheckingLocation)
                    .padding(Spacing.lg)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisited)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCheckingLocation)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 220)
        .clipped()
        .background(Color(UIColor.systemBackground))
    }
}
