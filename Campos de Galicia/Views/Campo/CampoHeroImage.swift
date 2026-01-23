import SwiftUI
import CoreLocation

/// Vista del hero image con badge de visita
struct CampoHeroImage: View {
    let imageURL: String
    let isVisited: Bool
    let isLoggedIn: Bool
    let onToggleVisit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: 220)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                        }
                        .frame(width: geometry.size.width, height: 220)
                    }
                }

                // Visit Badge
                if isLoggedIn {
                    Button(action: onToggleVisit) {
                        HStack(spacing: 6) {
                            Image(systemName: isVisited ? "checkmark.circle.fill" : "mappin.circle.fill")
                                .font(.caption)
                            Text(isVisited ? "Visitado" : "Marcar visita")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((isVisited ? Color.green : Color.blue).opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.25), radius: 4)
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 220)
    }
}
