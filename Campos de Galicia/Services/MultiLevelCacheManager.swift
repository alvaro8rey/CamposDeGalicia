import Foundation

// MARK: - Cache Configuration

/// Configuración para el sistema de caché multinivel
struct CacheConfig {
    let memoryCacheSize: Int        // Número máximo de items en memoria
    let memoryCacheTTL: TimeInterval // TTL para caché en memoria
    let diskCacheTTL: TimeInterval   // TTL para caché en disco
    let diskCacheMaxSize: Int        // Tamaño máximo en bytes para disco

    static let `default` = CacheConfig(
        memoryCacheSize: 50,
        memoryCacheTTL: 300,        // 5 minutos
        diskCacheTTL: 86400,        // 24 horas
        diskCacheMaxSize: 10_485_760 // 10 MB
    )

    static let aggressive = CacheConfig(
        memoryCacheSize: 100,
        memoryCacheTTL: 600,        // 10 minutos
        diskCacheTTL: 172800,       // 48 horas
        diskCacheMaxSize: 20_971_520 // 20 MB
    )

    static let conservative = CacheConfig(
        memoryCacheSize: 20,
        memoryCacheTTL: 120,        // 2 minutos
        diskCacheTTL: 43200,        // 12 horas
        diskCacheMaxSize: 5_242_880  // 5 MB
    )
}

/// Sistema de caché multinivel con memoria y disco
/// Nivel 1 (Memoria): Rápido, volátil, tamaño limitado
/// Nivel 2 (Disco): Persistente, más lento, mayor capacidad
@MainActor
final class MultiLevelCacheManager<T: Codable> {

    // MARK: - Cache Entry

    private struct CacheEntry {
        let value: T
        let timestamp: Date
        var accessCount: Int
        var lastAccessed: Date

        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }

    // MARK: - Properties

    private let config: CacheConfig
    private let cacheKey: String
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Memory Cache
    private var memoryCache: [String: CacheEntry] = [:]
    private var memoryAccessOrder: [String] = [] // Para LRU

    // Disk Cache Directory
    private let diskCacheDirectory: URL

    // Statistics
    private var stats: CacheStatistics = CacheStatistics()

    // MARK: - Initialization

    init(cacheKey: String, config: CacheConfig = .default, fileManager: FileManager = .default) {
        self.cacheKey = cacheKey
        self.config = config
        self.fileManager = fileManager

        // Setup encoder/decoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        // Setup disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.diskCacheDirectory = cachesDirectory.appendingPathComponent("MultiLevelCache/\(cacheKey)")

        // Create directory if needed
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)

        Logger.debug("MultiLevelCacheManager<\(T.self)> initialized for key: \(cacheKey)")
    }

    // MARK: - Get Methods

    /// Obtiene un valor del caché (verifica memoria primero, luego disco)
    func get(forKey key: String) -> T? {
        // Level 1: Memory Cache
        if let entry = getFromMemory(key) {
            stats.memoryHits += 1
            return entry.value
        }

        // Level 2: Disk Cache
        if let value = getFromDisk(key) {
            stats.diskHits += 1

            // Promote to memory cache
            set(value, forKey: key, skipDisk: true)

            return value
        }

        stats.misses += 1
        return nil
    }

    /// Obtiene múltiples valores del caché
    func getMultiple(forKeys keys: [String]) -> [String: T] {
        var results: [String: T] = [:]

        for key in keys {
            if let value = get(forKey: key) {
                results[key] = value
            }
        }

        return results
    }

    // MARK: - Set Methods

    /// Guarda un valor en el caché (memoria y opcionalmente disco)
    func set(_ value: T, forKey key: String, skipDisk: Bool = false) {
        // Save to memory
        setInMemory(value, forKey: key)

        // Save to disk if needed
        if !skipDisk {
            setInDisk(value, forKey: key)
        }

        stats.writes += 1
    }

    /// Guarda múltiples valores en el caché
    func setMultiple(_ values: [String: T]) {
        for (key, value) in values {
            set(value, forKey: key)
        }
    }

    // MARK: - Remove Methods

    /// Elimina un valor del caché
    func remove(forKey key: String) {
        removeFromMemory(key)
        removeFromDisk(key)
    }

    /// Elimina múltiples valores del caché
    func removeMultiple(forKeys keys: [String]) {
        for key in keys {
            remove(forKey: key)
        }
    }

    // MARK: - Clear Methods

    /// Limpia todo el caché (memoria y disco)
    func clearAll() {
        clearMemory()
        clearDisk()
        Logger.info("🗑️ Cleared all cache for key: \(cacheKey)")
    }

    /// Limpia solo el caché en memoria
    func clearMemory() {
        memoryCache.removeAll()
        memoryAccessOrder.removeAll()
        Logger.debug("🗑️ Memory cache cleared for key: \(cacheKey)")
    }

    /// Limpia solo el caché en disco
    func clearDisk() {
        do {
            let files = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            Logger.debug("🗑️ Disk cache cleared for key: \(cacheKey)")
        } catch {
            Logger.error("Error clearing disk cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Maintenance Methods

    /// Limpia entradas expiradas de memoria y disco
    func cleanExpired() {
        cleanExpiredMemory()
        cleanExpiredDisk()
    }

    /// Limpia entradas menos usadas del caché en memoria (LRU)
    func evictLRU(count: Int = 10) {
        guard memoryCache.count > config.memoryCacheSize else { return }

        // Ordenar por último acceso
        let sortedKeys = memoryCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            .prefix(count)
            .map { $0.key }

        for key in sortedKeys {
            removeFromMemory(key)
        }

        Logger.debug("🗑️ Evicted \(sortedKeys.count) LRU entries from memory")
    }

    // MARK: - Statistics

    /// Obtiene estadísticas del caché
    func getStatistics() -> CacheStatistics {
        var updatedStats = stats
        updatedStats.memoryCacheSize = memoryCache.count
        updatedStats.diskCacheSize = getDiskCacheSize()
        return updatedStats
    }

    /// Resetea las estadísticas
    func resetStatistics() {
        stats = CacheStatistics()
    }

    // MARK: - Private Methods (Memory)

    private func getFromMemory(_ key: String) -> CacheEntry? {
        guard var entry = memoryCache[key] else {
            return nil
        }

        // Verificar TTL
        if entry.age > config.memoryCacheTTL {
            removeFromMemory(key)
            return nil
        }

        // Actualizar estadísticas de acceso
        entry.accessCount += 1
        entry.lastAccessed = Date()
        memoryCache[key] = entry

        // Actualizar orden LRU
        memoryAccessOrder.removeAll { $0 == key }
        memoryAccessOrder.append(key)

        return entry
    }

    private func setInMemory(_ value: T, forKey key: String) {
        let entry = CacheEntry(
            value: value,
            timestamp: Date(),
            accessCount: 0,
            lastAccessed: Date()
        )

        memoryCache[key] = entry
        memoryAccessOrder.append(key)

        // Evict if over limit
        if memoryCache.count > config.memoryCacheSize {
            evictLRU(count: 1)
        }
    }

    private func removeFromMemory(_ key: String) {
        memoryCache.removeValue(forKey: key)
        memoryAccessOrder.removeAll { $0 == key }
    }

    private func cleanExpiredMemory() {
        let expiredKeys = memoryCache.filter { $0.value.age > config.memoryCacheTTL }.map { $0.key }
        for key in expiredKeys {
            removeFromMemory(key)
        }
        if !expiredKeys.isEmpty {
            Logger.debug("🗑️ Cleaned \(expiredKeys.count) expired entries from memory")
        }
    }

    // MARK: - Private Methods (Disk)

    private func diskFileURL(for key: String) -> URL {
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheDirectory.appendingPathComponent(safeKey + ".cache")
    }

    private func getFromDisk(_ key: String) -> T? {
        let fileURL = diskFileURL(for: key)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            // Verificar edad del archivo
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modificationDate)
                if age > config.diskCacheTTL {
                    removeFromDisk(key)
                    return nil
                }
            }

            let data = try Data(contentsOf: fileURL)
            let value = try decoder.decode(T.self, from: data)
            return value
        } catch {
            Logger.error("Error reading from disk cache: \(error.localizedDescription)")
            removeFromDisk(key) // Remove corrupted file
            return nil
        }
    }

    private func setInDisk(_ value: T, forKey key: String) {
        let fileURL = diskFileURL(for: key)

        do {
            let data = try encoder.encode(value)

            // Verificar tamaño antes de guardar
            let currentSize = getDiskCacheSize()
            if currentSize + data.count > config.diskCacheMaxSize {
                // Limpiar archivos viejos para hacer espacio
                cleanOldestDiskFiles(toFreeBytes: data.count)
            }

            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Logger.error("Error writing to disk cache: \(error.localizedDescription)")
        }
    }

    private func removeFromDisk(_ key: String) {
        let fileURL = diskFileURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }

    private func cleanExpiredDisk() {
        do {
            let files = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])

            var expiredCount = 0
            for file in files {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                if let modificationDate = attributes[.modificationDate] as? Date {
                    let age = Date().timeIntervalSince(modificationDate)
                    if age > config.diskCacheTTL {
                        try fileManager.removeItem(at: file)
                        expiredCount += 1
                    }
                }
            }

            if expiredCount > 0 {
                Logger.debug("🗑️ Cleaned \(expiredCount) expired files from disk")
            }
        } catch {
            Logger.error("Error cleaning expired disk cache: \(error.localizedDescription)")
        }
    }

    private func cleanOldestDiskFiles(toFreeBytes bytes: Int) {
        do {
            let files = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])

            // Ordenar por fecha de modificación (más viejo primero)
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return date1 < date2
            }

            var freedBytes = 0
            for file in sortedFiles {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                try fileManager.removeItem(at: file)
                freedBytes += size

                if freedBytes >= bytes {
                    break
                }
            }

            Logger.debug("🗑️ Freed \(freedBytes) bytes from disk cache")
        } catch {
            Logger.error("Error cleaning oldest disk files: \(error.localizedDescription)")
        }
    }

    private func getDiskCacheSize() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            return files.reduce(0) { total, file in
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + size
            }
        } catch {
            return 0
        }
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    var memoryHits: Int = 0
    var diskHits: Int = 0
    var misses: Int = 0
    var writes: Int = 0
    var memoryCacheSize: Int = 0
    var diskCacheSize: Int = 0

    var totalHits: Int {
        memoryHits + diskHits
    }

    var totalRequests: Int {
        totalHits + misses
    }

    var hitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalHits) / Double(totalRequests)
    }

    var memoryHitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(memoryHits) / Double(totalRequests)
    }
}

// MARK: - Cache Manager Factory

/// Factory para crear cache managers específicos
@MainActor
final class CacheManagerFactory {

    /// Singleton para campos
    static let camposCache = MultiLevelCacheManager<CampoModel>(
        cacheKey: "campos",
        config: .default
    )

    /// Singleton para contribuciones
    static let contribucionesCache = MultiLevelCacheManager<ContribucionAprobada>(
        cacheKey: "contribuciones",
        config: .conservative
    )

    /// Singleton para reseñas
    static let reseñasCache = MultiLevelCacheManager<Review>(
        cacheKey: "reseñas",
        config: .conservative
    )

    /// Limpia todos los cachés
    static func clearAllCaches() {
        camposCache.clearAll()
        contribucionesCache.clearAll()
        reseñasCache.clearAll()
    }

    /// Limpia cachés expirados en todos los managers
    static func cleanAllExpired() {
        camposCache.cleanExpired()
        contribucionesCache.cleanExpired()
        reseñasCache.cleanExpired()
    }

    /// Obtiene estadísticas de todos los cachés
    static func getAllStatistics() -> [String: CacheStatistics] {
        return [
            "campos": camposCache.getStatistics(),
            "contribuciones": contribucionesCache.getStatistics(),
            "reseñas": reseñasCache.getStatistics()
        ]
    }
}
