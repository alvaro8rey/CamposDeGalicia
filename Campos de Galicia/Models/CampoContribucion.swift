import Foundation

/// Modelo para una contribución de campo
struct CampoContribucion: Encodable {
    let id_usuario: String
    let id_campo: String
    let fotos_adicionales: [String]?
    let tiene_cantina: Bool?
    let aforo_grada: Int?
    let medidas_campo: String?
    let tipo_iluminacion: String?
    let estado_cesped: String?
    let accesibilidad: String?
    let notas: String?
    let fecha: Date
    let aprobada: Bool
}

/// Modelo para una contribución aprobada
struct ContribucionAprobada: Codable, Equatable {
    let id_usuario: String
    let fotos_adicionales: [String]?
    let tiene_cantina: Bool?
    let aforo_grada: Int?
    let medidas_campo: String?
    let tipo_iluminacion: String?
    let estado_cesped: String?
    let accesibilidad: String?
    let notas: String?
}

/// Modelo para el perfil de usuario simplificado
struct UserProfile: Decodable {
    let id: String?
    let nombre: String
}
