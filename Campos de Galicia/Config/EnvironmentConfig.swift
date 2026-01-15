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

        // 3. Usar valores por defecto (SOLO PARA DESARROLLO)
        // ⚠️ IMPORTANTE: Estas credenciales deben ser rotadas antes de producción
        if environment == .development {
            self.supabaseURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co"
            self.supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vcWRyaGt6c2V4am5tbnZwd3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYwMjk0MjEsImV4cCI6MjA2MTYwNTQyMX0.8jinhwjNaktc111FhV-_MEEiuCXynPiU88_7hMb6zcA"
            Logger.warning("⚠️ Usando credenciales por defecto (solo desarrollo)")
            return
        }

        // Si llegamos aquí en producción, es un error fatal
        fatalError("""
            ❌ No se encontraron credenciales de Supabase.

            Por favor configura las credenciales de una de estas formas:

            1. Variables de entorno:
               export SUPABASE_URL="tu_url"
               export SUPABASE_KEY="tu_key"

            2. Archivo Config.plist con:
               - SUPABASE_URL (String)
               - SUPABASE_KEY (String)

            Ver CREDENTIALS_SETUP.md para más información.
            """)
    }

    // MARK: - Validation
    func validate() -> Bool {
        guard !supabaseURL.isEmpty,
              supabaseURL.starts(with: "https://"),
              !supabaseKey.isEmpty,
              supabaseKey.count > 50 else {
            Logger.error("❌ Credenciales de Supabase inválidas")
            return false
        }
        return true
    }

    // MARK: - Debug Info
    var debugInfo: String {
        """
        Environment: \(environment.rawValue)
        Supabase URL: \(supabaseURL)
        Key Length: \(supabaseKey.count) characters
        Key Preview: \(supabaseKey.prefix(20))...
        """
    }
}
