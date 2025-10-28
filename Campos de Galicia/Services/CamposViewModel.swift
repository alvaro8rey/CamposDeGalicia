import Foundation
import Combine

@MainActor
final class CamposViewModel: ObservableObject {
    @Published private(set) var campos: [CampoModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published private(set) var campoExtras: [UUID: CampoDetailExtras] = [:]

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
        if let payload = await cacheStore.load() {
            campos = payload.campos
            lastUpdated = payload.lastUpdated
            campoExtras = payload.campoExtras
        } else if let cachedCampos = await supabaseManager.cachedCampos() {
            campos = cachedCampos.campos
            lastUpdated = cachedCampos.lastUpdated
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
        campoExtras.removeAll()
        await loadCampos(forceRefresh: true)
    }

    func campo(with id: UUID) -> CampoModel? {
        campos.first { $0.id == id }
    }

    func extras(for campoID: UUID) -> CampoDetailExtras? {
        campoExtras[campoID]
    }

    func loadExtras(for campoID: UUID, forceRefresh: Bool = false) async throws -> CampoDetailExtras {
        if !forceRefresh, let extras = campoExtras[campoID], isExtrasValid(extras) {
            return extras
        }

        if let cached = await cacheStore.loadExtras(for: campoID) {
            campoExtras[campoID] = cached
            if !forceRefresh, isExtrasValid(cached) {
                return cached
            }
        }

        do {
            let contribuciones = try await supabaseManager.fetchContribucionesAprobadas(for: campoID)
            let extras = CampoDetailExtras(contribuciones: contribuciones, lastUpdated: Date())
            campoExtras[campoID] = extras
            await cacheStore.saveExtras(extras, for: campoID)
            return extras
        } catch {
            if let cachedExtras = campoExtras[campoID] {
                return cachedExtras
            }
            if let cachedExtras = await cacheStore.loadExtras(for: campoID) {
                campoExtras[campoID] = cachedExtras
                return cachedExtras
            }
            throw error
        }
    }

    func invalidateExtras(for campoID: UUID) async {
        campoExtras.removeValue(forKey: campoID)
        await cacheStore.removeExtras(for: campoID)
    }

    private func isExtrasValid(_ extras: CampoDetailExtras) -> Bool {
        Date().timeIntervalSince(extras.lastUpdated) < extrasTTL
    }
}
