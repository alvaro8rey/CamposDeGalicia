import Foundation

// 1. Cambiamos de 'Decodable' a 'Codable' (Decodable + Encodable)
// 2. Cambiamos las propiedades editables de 'let' a 'var' para permitir la edición en la UI.
struct CampoModel: Codable, Equatable, Identifiable {
    let id: UUID // Se mantiene como let (la ID nunca cambia)
    var nombre: String
    var localidad: String
    var provincia: String
    var foto_url: String?
    var direccion: String
    var codigo_postal: String
    var superficie: String
    var tipo: String
    var latitud: Double?   // Latitud del campo
    var longitud: Double?  // Longitud del campo
    
    // Implementación de Equatable
    static func == (lhs: CampoModel, rhs: CampoModel) -> Bool {
        return lhs.id == rhs.id
    }
}


// Estructura auxiliar para la petición de UPDATE a Supabase.
// Permite que CampoEditView envíe solo los campos necesarios para la actualización
struct CampoUpdate: Encodable {
    var nombre: String?
    var localidad: String?
    var provincia: String?
    var foto_url: String?
    var direccion: String?
    var codigo_postal: String?
    var superficie: String?
    var tipo: String?
    var latitud: Double?
    var longitud: Double?
}
