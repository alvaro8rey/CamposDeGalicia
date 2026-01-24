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
            ZStack(alignment: .bottomLeading) {
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
                                colors: [Color.blue.opacity(0.3), Color.green.opacity(0.3)],
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
                        Color.black.opacity(0.6)
                    ]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 220)

                // Visit Badge con glassmorphism
                if isLoggedIn {
                    Button(action: onToggleVisit) {
                        HStack(spacing: 6) {
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                // Glassmorphism effect
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        (isVisited ? Color.green : Color.blue)
                                            .opacity(0.8)
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(isCheckingLocation)
                    .padding(16)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisited)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCheckingLocation)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 220)
    }
}
