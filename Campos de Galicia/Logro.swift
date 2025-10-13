import Foundation

public struct Logro: Identifiable, Codable {
    public let id: UUID
    public let nombre: String
    public let descripcion: String? // Opcional
    public let condicion: String?   // Opcional
    public let orden: Int?          // Cambiado a opcional
    public let xp: Int?             // Ya era opcional

    enum CodingKeys: String, CodingKey {
        case id
        case nombre
        case descripcion
        case condicion
        case orden
        case xp
    }
}

public struct LogroDesbloqueado: Identifiable, Codable {
    public let id: UUID
    public let id_usuario: UUID
    public let id_logro: UUID
    public let fecha_desbloqueo: Date

    enum CodingKeys: String, CodingKey {
        case id
        case id_usuario
        case id_logro
        case fecha_desbloqueo
    }
}

public struct NivelData: Codable {
    let id_usuario: String
    let level: Int
    let current_xp: Int
    let xp_to_next_level: Int

    enum CodingKeys: String, CodingKey {
        case id_usuario
        case level
        case current_xp
        case xp_to_next_level
    }
}

public struct AccesoDiario: Codable, Identifiable {
    public let id: UUID
    let id_usuario: UUID
    let ultimo_acceso: Date?
    let dias_consecutivos: Int
    let ultima_recompensa_reclamada: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case id_usuario
        case ultimo_acceso
        case dias_consecutivos
        case ultima_recompensa_reclamada
    }
}

public struct AccesoDiarioUpdate: Codable {
    let ultimo_acceso: String
    let dias_consecutivos: Int
    let ultima_recompensa_reclamada: String!

    enum CodingKeys: String, CodingKey {
        case ultimo_acceso
        case dias_consecutivos
        case ultima_recompensa_reclamada
    }
}
