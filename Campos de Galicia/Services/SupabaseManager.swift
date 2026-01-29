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
        // Limitar a 50 contribuciones más recientes por campo
        let response = try await client.from("campo_contribuciones")
            .select("*")
            .eq("id_campo", value: campoID.uuidString)
            .eq("aprobada", value: true)
            .order("fecha", ascending: false)
            .limit(limit)
            .execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ContribucionAprobada].self, from: response.data)
    }

    func invalidateCamposCache() async {
        await cacheStore.clear()
    }

    func cacheStoreInstance() -> CamposCacheStore {
        cacheStore
    }

    private func requestCampos() async throws -> [CampoModel] {
        // Sin límite para campos - necesitamos todos en el mapa
        // Pero agregamos order para optimización
        let response = try await client.from("campos")
            .select("*")
            .order("nombre", ascending: true)
            .execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CampoModel].self, from: response.data)
    }
}
