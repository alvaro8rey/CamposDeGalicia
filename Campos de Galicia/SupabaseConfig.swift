import Supabase
import Foundation

/// Cliente global de Supabase configurado con EnvironmentConfig
/// Las credenciales ahora se cargan de forma segura desde:
/// 1. Variables de entorno (recomendado para producción)
/// 2. Config.plist (para desarrollo local)
/// 3. Valores por defecto (solo desarrollo, requiere rotación antes de producción)
let supabase: SupabaseClient = {
    let config = EnvironmentConfig.shared

    // Validar credenciales
    guard config.validate() else {
        fatalError(L(.errorSupabaseCredentials))
    }

    // Log de configuración en modo debug
    if config.environment == .development {
        Logger.debug("Inicializando Supabase con configuración:\n\(config.debugInfo)")
    }

    guard let url = URL(string: config.supabaseURL) else {
        fatalError(L(.errorSupabaseInvalidURL, config.supabaseURL))
    }

    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: config.supabaseKey
    )
}()
