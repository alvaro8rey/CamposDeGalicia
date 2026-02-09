import Foundation

/// Errores relacionados con la configuración de la aplicación
enum AppConfigError: LocalizedError {
    case missingCredentials
    case invalidURL(String)
    case invalidCredentials
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return """
            No se encontraron credenciales de Supabase.

            Por favor configura las credenciales de una de estas formas:

            1. Variables de entorno:
               export SUPABASE_URL="tu_url"
               export SUPABASE_KEY="tu_key"

            2. Archivo Config.plist con:
               - SUPABASE_URL (String)
               - SUPABASE_KEY (String)

            3. Copia Config.plist.example a Config.plist y actualiza tus credenciales

            Ver README.md para más información.
            """

        case .invalidURL(let url):
            return "URL de Supabase inválida: \(url)"

        case .invalidCredentials:
            return "Las credenciales de Supabase no son válidas"

        case .missingConfiguration:
            return "No se pudo cargar la configuración de la aplicación"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingCredentials, .invalidCredentials:
            return "Verifica que las credenciales estén correctamente configuradas en Config.plist o como variables de entorno."
        case .invalidURL:
            return "Verifica que la URL comience con https:// y sea válida."
        case .missingConfiguration:
            return "Contacta al administrador del sistema."
        }
    }
}
