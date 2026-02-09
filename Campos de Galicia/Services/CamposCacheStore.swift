import Foundation

/// Extras de un campo (contribuciones)
/// Solo se mantiene en memoria, NO en disco
struct CampoDetailExtras: Codable, Equatable {
    var contribuciones: [ContribucionAprobada]
    var lastUpdated: Date
}

/// Sistema de caché optimizado para campos
/// ⚠️ Solo cachea la lista principal de campos con límites de tamaño
/// ✅ Los extras (contribuciones) solo se mantienen en memoria
actor CamposCacheStore {

    // MARK: - Cache Payload
    struct CamposPayload: Codable {
        var campos: [CampoModel]
        var lastUpdated: Date
        var cacheVersion: Int = 1  // Para invalidar caché en futuras actualizaciones
    }

    // MARK: - Properties
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxCacheSize: Int = 10 * 1024 * 1024  // 10 MB máximo

    // MARK: - Initialization
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        // Usar cachesDirectory (se limpia automáticamente cuando el sistema necesita espacio)
        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        self.fileURL = directory.appendingPathComponent("CamposList.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        Logger.debug("CamposCacheStore inicializado en: \(fileURL.path)")

        // Limpiar caché viejo si existe
        cleanOldCacheFiles()
    }

    // MARK: - Load Methods

    /// Carga la lista de campos desde caché
    func loadCampos() -> (campos: [CampoModel], lastUpdated: Date)? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            Logger.debug("Cache file no existe")
            return nil
        }

        do {
            // Verificar tamaño del archivo
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0

            if fileSize > maxCacheSize {
                Logger.warning("⚠️ Cache excede tamaño máximo (\(fileSize) bytes), limpiando...")
                clear()
                return nil
            }

            let data = try Data(contentsOf: fileURL)
            let payload = try decoder.decode(CamposPayload.self, from: data)

            let sizeInMB = Double(data.count) / (1024.0 * 1024.0)
            Logger.debug("✅ Cache cargado: \(payload.campos.count) campos, \(String(format: "%.2f", sizeInMB)) MB")
            return (payload.campos, payload.lastUpdated)

        } catch {
            Logger.error("❌ Error al cargar cache: \(error.localizedDescription)")
            // Si hay error de lectura, limpiar el caché corrupto
            clear()
            return nil
        }
    }

    // MARK: - Save Methods

    /// Guarda la lista de campos en caché
    /// Solo se guarda la lista principal, NO los extras de cada campo
    func saveCampos(_ campos: [CampoModel], lastUpdated: Date) {
        let payload = CamposPayload(
            campos: campos,
            lastUpdated: lastUpdated
        )

        do {
            let data = try encoder.encode(payload)
            let sizeInMB = Double(data.count) / (1024.0 * 1024.0)

            // Verificar que no exceda el tamaño máximo
            if data.count > maxCacheSize {
                Logger.warning("⚠️ Cache demasiado grande (\(String(format: "%.2f", sizeInMB)) MB), no guardando")
                return
            }

            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])

            Logger.debug("✅ Cache guardado: \(campos.count) campos, \(String(format: "%.2f", sizeInMB)) MB")

        } catch {
            Logger.error("❌ Error al guardar cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear Methods

    /// Limpia todo el caché
    func clear() {
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                Logger.info("🗑️ Cache limpiado")
            }
        } catch {
            Logger.error("❌ Error al limpiar cache: \(error.localizedDescription)")
        }
    }

    /// Limpia archivos de caché viejos
    private func cleanOldCacheFiles() {
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let oldCacheFile = cacheDir.appendingPathComponent("CamposCache.json")
        if fileManager.fileExists(atPath: oldCacheFile.path) {
            do {
                try fileManager.removeItem(at: oldCacheFile)
                Logger.info("🗑️ Cache viejo eliminado: CamposCache.json")
            } catch {
                Logger.error("Error al eliminar cache viejo: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Info Methods

    /// Obtiene información sobre el caché actual
    func cacheInfo() -> (exists: Bool, sizeBytes: Int, itemCount: Int) {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return (false, 0, 0)
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0

            if let payload = try? Data(contentsOf: fileURL),
               let decoded = try? decoder.decode(CamposPayload.self, from: payload) {
                return (true, fileSize, decoded.campos.count)
            }

            return (true, fileSize, 0)
        } catch {
            return (false, 0, 0)
        }
    }
}
