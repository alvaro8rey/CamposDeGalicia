import Foundation
import Combine

/// ✅ FIX: Actor para cache thread-safe de extras
private actor ExtrasCache {
    private var cache: [UUID: CampoDetailExtras] = [:]

    func get(_ key: UUID) -> CampoDetailExtras? {
        cache[key]
    }

    func set(_ key: UUID, value: CampoDetailExtras) {
        cache[key] = value
    }

    func remove(_ key: UUID) {
        cache.removeValue(forKey: key)
    }

    func removeAll() {
        cache.removeAll()
    }

    func removeExpired(isValid: (CampoDetailExtras) -> Bool) -> Int {
        let expiredKeys = cache.filter { !isValid($0.value) }.map { $0.key }
        expiredKeys.forEach { cache.removeValue(forKey: $0) }
        return expiredKeys.count
    }
}

@MainActor
final class CamposViewModel: ObservableObject {
    @Published private(set) var campos: [CampoModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    // ✅ FIX: Usar actor para evitar data race
    private let extrasCache = ExtrasCache()

    private let supabaseManager: SupabaseManager
    private let cacheStore: CamposCacheStore
    private let extrasTTL: TimeInterval

    init(supabaseManager: SupabaseManager? = nil, cacheStore: CamposCacheStore? = nil, extrasTTL: TimeInterval = 60 * 60 * 24) {
        if let cacheStore = cacheStore, let supabaseManager = supabaseManager {
            self.cacheStore = cacheStore
            self.supabaseManager = supabaseManager
        } else if let cacheStore = cacheStore {
            self.cacheStore = cacheStore
            self.supabaseManager = SupabaseManager(cacheStore: cacheStore)
        } else if let supabaseManager = supabaseManager {
            self.supabaseManager = supabaseManager
            self.cacheStore = supabaseManager.cacheStoreInstance()
        } else {
            let store = CamposCacheStore()
            self.cacheStore = store
            self.supabaseManager = SupabaseManager(cacheStore: store)
        }
        self.extrasTTL = extrasTTL

        Task {
            await loadCachedData()
        }
    }

    func loadCachedData() async {
        if let cachedCampos = await supabaseManager.cachedCampos() {
            campos = cachedCampos.campos
            lastUpdated = cachedCampos.lastUpdated
            Logger.debug("Cached campos loaded: \(campos.count) campos")
        }
    }

    func loadCampos(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        if !forceRefresh, let cached = await supabaseManager.cachedCampos() {
            campos = cached.campos
            lastUpdated = cached.lastUpdated
            errorMessage = nil
            if supabaseManager.isCacheValid(cached.lastUpdated) {
                return
            }
        }

        do {
            let result = try await supabaseManager.fetchCampos(forceRefresh: forceRefresh)
            campos = result.campos
            lastUpdated = result.lastUpdated
            errorMessage = result.error?.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
            if campos.isEmpty {
                campos = []
            }
        }
    }

    func refreshCampos() async {
        await supabaseManager.invalidateCamposCache()
        await extrasCache.removeAll()
        await loadCampos(forceRefresh: true)
    }

    /// Limpia el caché de extras expirados para liberar memoria
    func cleanExpiredExtras() async {
        let count = await extrasCache.removeExpired(isValid: isExtrasValid)
        if count > 0 {
            Logger.debug("🗑️ Cleaned \(count) expired extras from memory")
        }
    }

    func campo(with id: UUID) -> CampoModel? {
        campos.first { $0.id == id }
    }

    func extras(for campoID: UUID) async -> CampoDetailExtras? {
        await extrasCache.get(campoID)
    }

    /// Carga los extras de un campo (contribuciones)
    /// ✅ Mantiene caché en memoria con TTL
    /// ❌ NO guarda en disco (evita crecimiento exponencial)
    func loadExtras(for campoID: UUID, forceRefresh: Bool = false) async throws -> CampoDetailExtras {
        // Si está en memoria y es válido, devolver
        if !forceRefresh, let extras = await extrasCache.get(campoID), isExtrasValid(extras) {
            Logger.debug("✅ Extras from memory cache for campo: \(campoID)")
            return extras
        }

        // Siempre fetch desde servidor
        Logger.debug("📡 Fetching extras from server for campo: \(campoID)")
        do {
            let contribuciones = try await supabaseManager.fetchContribucionesAprobadas(for: campoID)
            let extras = CampoDetailExtras(contribuciones: contribuciones, lastUpdated: Date())

            // Solo guardar en memoria (NO en disco)
            await extrasCache.set(campoID, value: extras)

            Logger.debug("✅ Extras loaded: \(contribuciones.count) contribuciones")
            return extras
        } catch {
            // Si hay error y tenemos caché en memoria (aunque esté expirado), usarlo
            if let cachedExtras = await extrasCache.get(campoID) {
                Logger.warning("⚠️ Using expired memory cache due to error: \(error.localizedDescription)")
                return cachedExtras
            }
            throw error
        }
    }

    /// Invalida el caché en memoria de extras para un campo
    func invalidateExtras(for campoID: UUID) async {
        await extrasCache.remove(campoID)
        Logger.debug("🗑️ Memory cache invalidated for campo: \(campoID)")
    }

    private func isExtrasValid(_ extras: CampoDetailExtras) -> Bool {
        Date().timeIntervalSince(extras.lastUpdated) < extrasTTL
    }
}
