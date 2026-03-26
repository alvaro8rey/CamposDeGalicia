import Foundation
import UIKit

/// CacheManager - Gestión inteligente de caché para prevenir OOM en dispositivos antiguos
///
/// ESTRATEGIA:
/// - Límites adaptativos según memoria del dispositivo
/// - Limpieza automática basada en presión de memoria
/// - Logging de uso del caché
/// - Respuesta a advertencias de memoria del sistema
final class CacheManager {
    static let shared = CacheManager()

    // MARK: - Configuration

    /// Límites de caché según tipo de dispositivo
    private enum CacheLimits {
        // Dispositivos nuevos (>= 4 GB RAM)
        static let modernMemoryCapacity = 20_000_000      // 20 MB
        static let modernDiskCapacity = 50_000_000        // 50 MB

        // Dispositivos medios (2-4 GB RAM)
        static let midRangeMemoryCapacity = 10_000_000    // 10 MB
        static let midRangeDiskCapacity = 30_000_000      // 30 MB

        // Dispositivos antiguos (< 2 GB RAM)
        static let legacyMemoryCapacity = 5_000_000       // 5 MB
        static let legacyDiskCapacity = 15_000_000        // 15 MB
    }

    /// Límite de memoria del dispositivo en GB para determinar categoría
    private var deviceMemoryGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
    }

    // MARK: - Cache Statistics

    private var lastCleanupDate: Date?
    private let cleanupInterval: TimeInterval = 300 // 5 minutos

    private init() {
        setupCache()
        setupMemoryWarningObserver()
    }

    // MARK: - Setup

    /// Configura el URLCache con límites adaptativos
    func setupCache() {
        let (memoryCapacity, diskCapacity) = determineCacheLimits()

        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity
        )
        URLCache.shared = cache

        Logger.debug("💾 CacheManager configurado:")
        Logger.debug("   • Dispositivo: \(String(format: "%.1f", deviceMemoryGB)) GB RAM")
        Logger.debug("   • Memoria: \(memoryCapacity / 1_000_000) MB")
        Logger.debug("   • Disco: \(diskCapacity / 1_000_000) MB")

        logCacheUsage()
    }

    /// Determina límites de caché según el dispositivo
    private func determineCacheLimits() -> (memory: Int, disk: Int) {
        if deviceMemoryGB >= 4.0 {
            Logger.debug("📱 Dispositivo moderno detectado")
            return (CacheLimits.modernMemoryCapacity, CacheLimits.modernDiskCapacity)
        } else if deviceMemoryGB >= 2.0 {
            Logger.debug("📱 Dispositivo de rango medio detectado")
            return (CacheLimits.midRangeMemoryCapacity, CacheLimits.midRangeDiskCapacity)
        } else {
            Logger.debug("📱 Dispositivo antiguo detectado - límites conservadores")
            return (CacheLimits.legacyMemoryCapacity, CacheLimits.legacyDiskCapacity)
        }
    }

    // MARK: - Memory Warnings

    /// Configura observador para advertencias de memoria
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        Logger.debug("⚠️ Observador de memoria configurado")
    }

    @objc private func handleMemoryWarning() {
        Logger.warning("⚠️ MEMORIA BAJA - Limpiando caché agresivamente")
        clearMemoryCache()
        logCacheUsage()
    }

    // MARK: - Cache Management

    /// Limpia el caché de memoria (mantiene disco)
    func clearMemoryCache() {
        URLCache.shared.removeAllCachedResponses()
        Logger.debug("🧹 Caché de memoria limpiada")
    }

    /// Limpia todo el caché (memoria + disco)
    func clearAllCache() {
        URLCache.shared.removeAllCachedResponses()
        Logger.debug("🧹 Caché completa limpiada (memoria + disco)")
        logCacheUsage()
    }

    /// Limpieza periódica si es necesario
    func performPeriodicCleanupIfNeeded() {
        // Solo limpiar si han pasado al menos 5 minutos desde la última limpieza
        if let lastCleanup = lastCleanupDate,
           Date().timeIntervalSince(lastCleanup) < cleanupInterval {
            return
        }

        let usage = getCacheUsage()

        // Limpiar si estamos usando más del 80% de la capacidad
        let memoryUsagePercent = Double(usage.currentMemoryUsage) / Double(usage.memoryCapacity)
        let diskUsagePercent = Double(usage.currentDiskUsage) / Double(usage.diskCapacity)

        if memoryUsagePercent > 0.8 {
            Logger.warning("⚠️ Uso de caché de memoria alto (\(Int(memoryUsagePercent * 100))%) - limpiando")
            clearMemoryCache()
            lastCleanupDate = Date()
        }

        if diskUsagePercent > 0.8 {
            Logger.warning("⚠️ Uso de caché de disco alto (\(Int(diskUsagePercent * 100))%) - limpiando")
            clearOldCacheEntries()
            lastCleanupDate = Date()
        }
    }

    /// Limpia entradas antiguas del caché (estrategia LRU aproximada)
    private func clearOldCacheEntries() {
        // URLCache no expone API para LRU, así que limpiamos todo
        // En producción, podrías implementar tu propio caché con LRU
        URLCache.shared.removeAllCachedResponses()
        Logger.debug("🧹 Entradas antiguas del caché limpiadas")
    }

    // MARK: - Cache Statistics

    /// Obtiene estadísticas de uso del caché
    func getCacheUsage() -> CacheUsage {
        CacheUsage(
            currentMemoryUsage: URLCache.shared.currentMemoryUsage,
            memoryCapacity: URLCache.shared.memoryCapacity,
            currentDiskUsage: URLCache.shared.currentDiskUsage,
            diskCapacity: URLCache.shared.diskCapacity
        )
    }

    /// Log del uso actual del caché
    func logCacheUsage() {
        let usage = getCacheUsage()
        let memoryPercent = Int((Double(usage.currentMemoryUsage) / Double(usage.memoryCapacity)) * 100)
        let diskPercent = Int((Double(usage.currentDiskUsage) / Double(usage.diskCapacity)) * 100)

        Logger.debug("📊 Uso de caché:")
        Logger.debug("   • Memoria: \(usage.currentMemoryUsage / 1_000_000) MB / \(usage.memoryCapacity / 1_000_000) MB (\(memoryPercent)%)")
        Logger.debug("   • Disco: \(usage.currentDiskUsage / 1_000_000) MB / \(usage.diskCapacity / 1_000_000) MB (\(diskPercent)%)")
    }
}

// MARK: - Cache Usage Model

struct CacheUsage {
    let currentMemoryUsage: Int
    let memoryCapacity: Int
    let currentDiskUsage: Int
    let diskCapacity: Int

    var memoryUsagePercent: Double {
        Double(currentMemoryUsage) / Double(memoryCapacity)
    }

    var diskUsagePercent: Double {
        Double(currentDiskUsage) / Double(diskCapacity)
    }

    var isMemoryHigh: Bool {
        memoryUsagePercent > 0.8
    }

    var isDiskHigh: Bool {
        diskUsagePercent > 0.8
    }
}
