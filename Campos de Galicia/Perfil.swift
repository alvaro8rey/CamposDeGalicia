import Foundation

struct Perfil: Codable {
    let id: String
    var nombre: String // ⭐️ CORRECCIÓN: Cambiado a 'var'
    var apellidos: String // ⭐️ CORRECCIÓN: Cambiado a 'var'
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nombre
        case apellidos
        case isAdmin = "is_admin"
    }
}
