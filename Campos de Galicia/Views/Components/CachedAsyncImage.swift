import SwiftUI
import UIKit

/// CachedAsyncImage - Componente optimizado para cargar imágenes con caché y downsample
///
/// OPTIMIZACIONES DE MEMORIA:
/// - Downsample: redimensiona imágenes ANTES de cargarlas en memoria
/// - Caché: usa URLCache para evitar descargas repetidas
/// - Lazy loading: solo carga cuando la vista aparece
///
/// Uso:
/// ```swift
/// CachedAsyncImage(url: URL(string: "https://..."), targetSize: CGSize(width: 60, height: 60)) { image in
///     image.resizable().aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Color.gray.opacity(0.3)
/// }
/// ```
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let targetSize: CGSize?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var loadingFailed: Bool = false

    init(
        url: URL?,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else if loadingFailed {
                // Error state - imagen no cargada
                ZStack {
                    Color.gray.opacity(0.15)

                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No disponible")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
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
        if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)) {
            if let downsampledImage = downsampleImage(data: cachedResponse.data, to: targetSize) {
                Logger.debug("✅ Imagen cargada desde caché (downsampled): \(url.lastPathComponent)")
                DispatchQueue.main.async {
                    self.loadedImage = downsampledImage
                    self.isLoading = false
                }

                // Verificar uso del caché periódicamente
                CacheManager.shared.performPeriodicCleanupIfNeeded()
                return
            }
        }

        // Si no está en caché, descargar
        Logger.debug("📥 Descargando imagen: \(url.lastPathComponent)")
        URLSession.shared.dataTask(with: url) { [targetSize] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }

            guard let data = data,
                  let response = response,
                  error == nil else {
                Logger.warning("⚠️ Error cargando imagen: \(error?.localizedDescription ?? "desconocido")")
                DispatchQueue.main.async {
                    self.loadingFailed = true
                }
                return
            }

            // Guardar en caché los datos originales
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: URLRequest(url: url))

            // Downsample para reducir memoria
            guard let downsampledImage = downsampleImage(data: data, to: targetSize) else {
                Logger.warning("⚠️ Error procesando imagen")
                DispatchQueue.main.async {
                    self.loadingFailed = true
                }
                return
            }

            Logger.debug("✅ Imagen descargada y redimensionada: \(url.lastPathComponent)")
            DispatchQueue.main.async {
                self.loadedImage = downsampledImage
            }
        }.resume()
    }

    /// Downsample image para reducir uso de memoria
    /// Redimensiona la imagen ANTES de decodificarla completamente
    private func downsampleImage(data: Data, to targetSize: CGSize?) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Si no hay targetSize, usar tamaño original pero con límite
        let maxDimension: CGFloat = targetSize.map { max($0.width, $0.height) * 2 } ?? 800

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            // Fallback: cargar imagen normal pero con límite
            guard let image = UIImage(data: data) else { return nil }
            return resizeImage(image, to: targetSize ?? CGSize(width: 800, height: 800))
        }

        return UIImage(cgImage: downsampledImage)
    }

    /// Fallback: redimensionar UIImage si downsample falla
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? image
    }
}

// MARK: - Variante con escala personalizada
extension CachedAsyncImage where Placeholder == Color {
    init(
        url: URL?,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.targetSize = targetSize
        self.content = content
        self.placeholder = { Color.gray.opacity(0.3) }
    }
}

// MARK: - Preview
struct CachedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Con downsample para lista (60x60)
            CachedAsyncImage(
                url: URL(string: "https://picsum.photos/800/600"),
                targetSize: CGSize(width: 60, height: 60)
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } placeholder: {
                Color.blue.opacity(0.2)
                    .overlay {
                        ProgressView()
                    }
            }

            // Con downsample para tarjeta (200x150)
            CachedAsyncImage(
                url: URL(string: "https://picsum.photos/800/600"),
                targetSize: CGSize(width: 200, height: 150)
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(width: 200, height: 150)
        }
        .padding()
    }
}
