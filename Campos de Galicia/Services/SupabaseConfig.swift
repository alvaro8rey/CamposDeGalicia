import Supabase
import Foundation

/// URL de fallback para Supabase cuando la configuración falla
/// Esta URL nunca debe usarse en producción - solo para desarrollo cuando Config.plist está ausente
private let fallbackSupabaseURL: URL = {
    // Esta URL hardcodeada es segura porque sabemos que es una URL válida
    // y solo se usa en casos de error de configuración
    guard let url = URL(string: "https://placeholder.supabase.co") else {
        // Si incluso esta URL falla, es un error de programación crítico
        fatalError("Failed to create fallback Supabase URL - this should never happen")
    }
    return url
}()

/// Cliente global de Supabase configurado con EnvironmentConfig
/// Las credenciales ahora se cargan de forma segura desde:
/// 1. Variables de entorno (recomendado para producción)
/// 2. Config.plist (para desarrollo local)
/// 3. Valores por defecto (solo desarrollo, requiere rotación antes de producción)
let supabase: SupabaseClient = {
    let config = EnvironmentConfig.shared

    do {
        // Validar credenciales
        try config.validate()

        // Log de configuración en modo debug (sin exponer credenciales)
        if config.environment == .development {
            Logger.debug("Inicializando Supabase con configuración:\n\(config.debugInfo)")
        }

        guard let url = URL(string: config.supabaseURL) else {
            Logger.error("❌ URL de Supabase inválida")
            // En lugar de crash, usar URL temporal y permitir que los errores de red se manejen más adelante
            return SupabaseClient(supabaseURL: fallbackSupabaseURL, supabaseKey: "")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.supabaseKey
        )
    } catch {
        Logger.error("❌ Error al configurar Supabase: \(error.localizedDescription)")

        // En lugar de crash inmediato, crear cliente con placeholder
        // Los errores de autenticación se manejarán en tiempo de ejecución
        return SupabaseClient(supabaseURL: fallbackSupabaseURL, supabaseKey: "")
    }
}()
