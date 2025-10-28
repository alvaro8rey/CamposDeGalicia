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
        let cachedPayload = await cacheStore.load()

        if !forceRefresh, let cachedPayload = cachedPayload, isCacheValid(cachedPayload.lastUpdated) {
            return CamposFetchResult(
                campos: cachedPayload.campos,
                lastUpdated: cachedPayload.lastUpdated,
                source: .cache,
                cacheValid: true,
                error: nil
            )
        }

        do {
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
            if let cachedPayload = cachedPayload {
                return CamposFetchResult(
                    campos: cachedPayload.campos,
                    lastUpdated: cachedPayload.lastUpdated,
                    source: .cache,
                    cacheValid: false,
                    error: error
                )
            }
            throw error
        }
    }

    func fetchContribucionesAprobadas(for campoID: UUID) async throws -> [ContribucionAprobada] {
        let response = try await client.from("campo_contribuciones")
            .select("*")
            .eq(column: "id_campo", value: campoID.uuidString)
            .eq(column: "aprobada", value: true)
            .order(column: "fecha", ascending: false)
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
        let response = try await client.from("campos").select("*").execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CampoModel].self, from: response.data)
    }
}
