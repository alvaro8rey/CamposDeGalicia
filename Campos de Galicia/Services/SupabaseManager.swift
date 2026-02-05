import Foundation
import Supabase

struct CamposFetchResult {
    enum Source {
        case cache
        case remote
    }

    let campos: [CampoModel]
    let lastUpdated: Date
    let source: Source
    let cacheValid: Bool
    let error: Error?
}

final class SupabaseManager {
    private let client: SupabaseClient
    private let cacheStore: CamposCacheStore
    private let cacheTTL: TimeInterval

    init(client: SupabaseClient = supabase, cacheStore: CamposCacheStore = CamposCacheStore(), cacheTTL: TimeInterval = 60 * 60 * 24) {
        self.client = client
        self.cacheStore = cacheStore
        self.cacheTTL = cacheTTL
    }

    func cachedCampos() async -> (campos: [CampoModel], lastUpdated: Date)? {
        await cacheStore.loadCampos()
    }

    func isCacheValid(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < cacheTTL
    }

    func fetchCampos(forceRefresh: Bool = false) async throws -> CamposFetchResult {
        let cachedData = await cacheStore.loadCampos()

        if !forceRefresh, let cached = cachedData, isCacheValid(cached.lastUpdated) {
            Logger.debug("✅ Usando caché válido: \(cached.campos.count) campos")
            return CamposFetchResult(
                campos: cached.campos,
                lastUpdated: cached.lastUpdated,
                source: .cache,
                cacheValid: true,
                error: nil
            )
        }

        do {
            Logger.debug("📡 Fetching campos desde servidor")
            let campos = try await requestCampos()
            let sorted = campos.sorted { $0.nombre.lowercased() < $1.nombre.lowercased() }
            let timestamp = Date()
            await cacheStore.saveCampos(sorted, lastUpdated: timestamp)
            return CamposFetchResult(
                campos: sorted,
                lastUpdated: timestamp,
                source: .remote,
                cacheValid: true,
                error: nil
            )
        } catch {
            if let cached = cachedData {
                Logger.warning("⚠️ Error al obtener campos, usando caché expirado: \(error.localizedDescription)")
                return CamposFetchResult(
                    campos: cached.campos,
                    lastUpdated: cached.lastUpdated,
                    source: .cache,
                    cacheValid: false,
                    error: error
                )
            }
            throw error
        }
    }

    func fetchContribucionesAprobadas(for campoID: UUID, limit: Int = 50) async throws -> [ContribucionAprobada] {
        // Usar query optimizada con paginación
        let config = SupabaseQueryOptimizer.PaginationConfig(pageSize: limit, maxPages: 1)
        let result = try await SupabaseQueryOptimizer.fetchContribucionesPaginated(
            client: client,
            campoID: campoID,
            page: 0,
            config: config,
            onlyApproved: true
        )
        return result.items
    }

    /// Fetch contribuciones con paginación completa
    func fetchContribucionesPaginadas(
        for campoID: UUID,
        page: Int = 0,
        pageSize: Int = 20
    ) async throws -> SupabaseQueryOptimizer.PaginatedResult<ContribucionAprobada> {
        let config = SupabaseQueryOptimizer.PaginationConfig(pageSize: pageSize, maxPages: nil)
        return try await SupabaseQueryOptimizer.fetchContribucionesPaginated(
            client: client,
            campoID: campoID,
            page: page,
            config: config,
            onlyApproved: true
        )
    }

    func invalidateCamposCache() async {
        await cacheStore.clear()
    }

    func cacheStoreInstance() -> CamposCacheStore {
        cacheStore
    }

    private func requestCampos() async throws -> [CampoModel] {
        // Usar query optimizada con medición de tiempo
        let (campos, duration) = try await SupabaseQueryOptimizer.measureQueryTime(operation: "fetch_all_campos") {
            try await SupabaseQueryOptimizer.fetchCamposOptimized(
                client: client,
                orderBy: "nombre",
                ascending: true
            )
        }

        Logger.debug("Fetched \(campos.count) campos in \(String(format: "%.2f", duration))s")
        return campos
    }

    /// Fetch campos cercanos optimizado
    func fetchCamposCercanos(
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 10,
        limit: Int = 50
    ) async throws -> [CampoModel] {
        return try await SupabaseQueryOptimizer.fetchCamposCercanos(
            client: client,
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
            limit: limit
        )
    }

    /// Fetch incremental - solo campos actualizados desde la última sincronización
    func fetchCamposIncrementales(since: Date) async throws -> [CampoModel] {
        return try await SupabaseQueryOptimizer.fetchCamposIncremental(
            client: client,
            since: since
        )
    }

    /// Fetch múltiples campos por IDs en batch
    func fetchCamposByIDs(_ ids: [UUID]) async throws -> [CampoModel] {
        guard !ids.isEmpty else { return [] }
        return try await SupabaseQueryOptimizer.fetchCamposByIDs(
            client: client,
            ids: ids
        )
    }
}
