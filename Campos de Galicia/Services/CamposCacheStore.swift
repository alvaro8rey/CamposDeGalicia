import Foundation

struct CampoDetailExtras: Codable, Equatable {
    var contribuciones: [ContribucionAprobada]
    var lastUpdated: Date
}

actor CamposCacheStore {
    struct Payload: Codable {
        var campos: [CampoModel]
        var lastUpdated: Date
        var campoExtras: [UUID: CampoDetailExtras]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.fileURL = directory.appendingPathComponent("CamposCache.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> Payload? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(Payload.self, from: data)
        } catch {
            print("CamposCacheStore.load error: \(error)")
            return nil
        }
    }

    func loadCampos() -> (campos: [CampoModel], lastUpdated: Date)? {
        guard let payload = load() else { return nil }
        return (payload.campos, payload.lastUpdated)
    }

    func loadExtras(for campoID: UUID) -> CampoDetailExtras? {
        return load()?.campoExtras[campoID]
    }

    func saveCampos(_ campos: [CampoModel], lastUpdated: Date) {
        var payload = load() ?? Payload(campos: [], lastUpdated: .distantPast, campoExtras: [:])
        payload.campos = campos
        payload.lastUpdated = lastUpdated
        write(payload)
    }

    func saveExtras(_ extras: CampoDetailExtras, for campoID: UUID) {
        var payload = load() ?? Payload(campos: [], lastUpdated: .distantPast, campoExtras: [:])
        payload.campoExtras[campoID] = extras
        write(payload)
    }

    func removeExtras(for campoID: UUID) {
        guard var payload = load() else { return }
        payload.campoExtras.removeValue(forKey: campoID)
        write(payload)
    }

    func clear() {
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("CamposCacheStore.clear error: \(error)")
        }
    }

    private func write(_ payload: Payload) {
        do {
            let data = try encoder.encode(payload)
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("CamposCacheStore.write error: \(error)")
        }
    }
}
