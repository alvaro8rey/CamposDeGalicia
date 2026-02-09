import Foundation

/// Configuración de entorno para la aplicación
/// Las credenciales se pueden configurar de tres formas (en orden de prioridad):
/// 1. Variables de entorno del sistema
/// 2. Archivo Config.plist (no incluido en git)
/// 3. Valores por defecto (solo para desarrollo)
struct EnvironmentConfig {

    // MARK: - Singleton
    static let shared = EnvironmentConfig()

    // MARK: - Properties
    let supabaseURL: String
    let supabaseKey: String
    let environment: Environment

    // MARK: - Environment Types
    enum Environment: String {
        case development = "Development"
        case production = "Production"

        var isProduction: Bool {
            self == .production
        }
    }

    // MARK: - Initialization
    private init() {
        // Detectar entorno
        #if DEBUG
        self.environment = .development
        #else
        self.environment = .production
        #endif

        do {
            // 1. Intentar cargar desde variables de entorno del sistema
            if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"],
               let envKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"],
               !envURL.isEmpty, !envKey.isEmpty {
                self.supabaseURL = envURL
                self.supabaseKey = envKey
                Logger.info("✅ Credenciales cargadas desde variables de entorno")
                return
            }

            // 2. Intentar cargar desde Config.plist
            if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
               let config = NSDictionary(contentsOfFile: configPath),
               let url = config["SUPABASE_URL"] as? String,
               let key = config["SUPABASE_KEY"] as? String,
               !url.isEmpty, !key.isEmpty {
                self.supabaseURL = url
                self.supabaseKey = key
                Logger.info("✅ Credenciales cargadas desde Config.plist")
                return
            }

            // 3. Si no hay credenciales disponibles, usar valores por defecto vacíos
            // y loguear el error para permitir que la app maneje esto gracefully
            Logger.error("❌ No se encontraron credenciales de Supabase")
            self.supabaseURL = ""
            self.supabaseKey = ""

            // En desarrollo, mostrar alerta al usuario en lugar de crash
            if environment == .development {
                Logger.warning("""
                    ⚠️ Credenciales de Supabase no configuradas.
                    La aplicación puede no funcionar correctamente.

                    Configura las credenciales en Config.plist o variables de entorno.
                    Ver README.md para más información.
                    """)
            }
        }
    }

    // MARK: - Validation
    func validate() throws {
        guard !supabaseURL.isEmpty else {
            throw AppConfigError.missingCredentials
        }

        guard supabaseURL.starts(with: "https://") else {
            throw AppConfigError.invalidURL(supabaseURL)
        }

        guard !supabaseKey.isEmpty, supabaseKey.count > 50 else {
            throw AppConfigError.invalidCredentials
        }
    }

    // MARK: - Debug Info
    /// Información de debug segura (sin exponer credenciales)
    var debugInfo: String {
        """
        Environment: \(environment.rawValue)
        Supabase URL: \(supabaseURL.isEmpty ? "No configurada" : "Configurada")
        Key Length: \(supabaseKey.count) characters
        """
    }
}
