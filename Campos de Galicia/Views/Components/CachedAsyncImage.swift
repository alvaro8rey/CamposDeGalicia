import SwiftUI

/// CachedAsyncImage - Componente optimizado para cargar imágenes con caché automático
///
/// Utiliza URLCache configurado globalmente en AppMain para:
/// - Cachear imágenes en memoria (50 MB)
/// - Cachear imágenes en disco (100 MB)
/// - Evitar descargas repetidas de las mismas imágenes
/// - Reducir uso de datos móviles
///
/// Uso:
/// ```swift
/// CachedAsyncImage(url: URL(string: "https://...")) { image in
///     image.resizable().aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Color.gray.opacity(0.3)
/// }
/// ```
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        isLoading = true

        // Intentar cargar desde caché primero
        if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)),
           let image = UIImage(data: cachedResponse.data) {
            Logger.debug("✅ Imagen cargada desde caché: \(url.lastPathComponent)")
            DispatchQueue.main.async {
                self.loadedImage = image
                self.isLoading = false
            }
            return
        }

        // Si no está en caché, descargar
        Logger.debug("📥 Descargando imagen: \(url.lastPathComponent)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }

            guard let data = data,
                  let response = response,
                  let image = UIImage(data: data),
                  error == nil else {
                Logger.warning("⚠️ Error cargando imagen: \(error?.localizedDescription ?? "desconocido")")
                return
            }

            // Guardar en caché
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: URLRequest(url: url))

            Logger.debug("✅ Imagen descargada y cacheada: \(url.lastPathComponent)")
            DispatchQueue.main.async {
                self.loadedImage = image
            }
        }.resume()
    }
}

// MARK: - Variante con escala personalizada
extension CachedAsyncImage where Placeholder == Color {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { Color.gray.opacity(0.3) }
    }
}

// MARK: - Preview
struct CachedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Con placeholder personalizado
            CachedAsyncImage(
                url: URL(string: "https://picsum.photos/400/300")
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } placeholder: {
                Color.blue.opacity(0.2)
                    .overlay {
                        ProgressView()
                    }
            }

            // Con placeholder por defecto
            CachedAsyncImage(url: URL(string: "https://picsum.photos/400/300")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(width: 200, height: 150)
        }
        .padding()
    }
}
