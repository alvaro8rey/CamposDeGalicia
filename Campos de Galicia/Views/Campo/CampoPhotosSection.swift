import SwiftUI

/// Vista de la sección de fotos adicionales del campo
struct CampoPhotosSection: View {
    let photos: [(url: String, userId: String)]
    let userNames: [String: String]
    let onPhotoTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "photo.stack.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Fotos")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(photos.indices, id: \.self) { index in
                        let foto = photos[index]
                        let nombre = userNames[foto.userId] ?? "Usuario desconocido"

                        VStack(spacing: 8) {
                            if let url = URL(string: foto.url) {
                                CachedAsyncImage(
                                    url: url,
                                    targetSize: CGSize(width: 260, height: 260)
                                ) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 130, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.15), radius: 4)
                                } placeholder: {
                                    ZStack {
                                        Color.gray.opacity(0.2)
                                        ProgressView()
                                    }
                                    .frame(width: 130, height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .onTapGesture {
                                    onPhotoTap(index)
                                }
                            }

                            Text("Por \(nombre)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}
