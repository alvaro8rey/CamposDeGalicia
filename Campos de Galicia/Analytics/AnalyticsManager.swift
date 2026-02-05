import Foundation
import UIKit

// MARK: - Firebase Import (comment out if not using Firebase)
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
import FirebaseCore
#endif

/// Sistema de analytics unificado con soporte para múltiples proveedores
/// Actualmente soporta: Logs locales + Firebase Analytics
class AnalyticsManager {

    // MARK: - Singleton
    static let shared = AnalyticsManager()

    // MARK: - Analytics Providers
    enum Provider {
        case localLogs
        case firebase
        case mixpanel

        var isAvailable: Bool {
            switch self {
            case .localLogs:
                return true
            case .firebase:
                #if canImport(FirebaseAnalytics)
                return true
                #else
                return false
                #endif
            case .mixpanel:
                return false // Implement when needed
            }
        }
    }

    // MARK: - Properties
    private let isEnabled: Bool
    private var sessionId: String
    private var sessionStartTime: Date
    private let enabledProviders: [Provider]

    // MARK: - Event Categories
    enum Category: String {
        case user = "User"
        case campo = "Campo"
        case achievement = "Achievement"
        case navigation = "Navigation"
        case error = "Error"
        case performance = "Performance"
    }

    // MARK: - Common Events
    enum Event {
        // User events
        case login(method: String)
        case logout
        case register
        case profileUpdate

        // Campo events
        case campoViewed(id: String, name: String)
        case campoVisited(id: String, name: String, method: String) // method: "manual" or "auto"
        case campoContributionAdded(id: String)

        // Achievement events
        case achievementUnlocked(id: String, name: String, xp: Int)
        case levelUp(newLevel: Int, totalXP: Int)
        case dailyRewardClaimed(day: Int, xp: Int)

        // Navigation events
        case screenViewed(name: String)
        case tabChanged(to: String)

        // Error events
        case error(type: String, message: String)
        case apiError(endpoint: String, statusCode: Int)

        // Performance events
        case appLaunched
        case dataLoaded(type: String, count: Int, duration: TimeInterval)

        var category: Category {
            switch self {
            case .login, .logout, .register, .profileUpdate:
                return .user
            case .campoViewed, .campoVisited, .campoContributionAdded:
                return .campo
            case .achievementUnlocked, .levelUp, .dailyRewardClaimed:
                return .achievement
            case .screenViewed, .tabChanged:
                return .navigation
            case .error, .apiError:
                return .error
            case .appLaunched, .dataLoaded:
                return .performance
            }
        }

        var name: String {
            switch self {
            case .login: return "login"
            case .logout: return "logout"
            case .register: return "register"
            case .profileUpdate: return "profile_update"
            case .campoViewed: return "campo_viewed"
            case .campoVisited: return "campo_visited"
            case .campoContributionAdded: return "campo_contribution_added"
            case .achievementUnlocked: return "achievement_unlocked"
            case .levelUp: return "level_up"
            case .dailyRewardClaimed: return "daily_reward_claimed"
            case .screenViewed: return "screen_viewed"
            case .tabChanged: return "tab_changed"
            case .error: return "error"
            case .apiError: return "api_error"
            case .appLaunched: return "app_launched"
            case .dataLoaded: return "data_loaded"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .login(let method):
                return ["method": method]
            case .campoViewed(let id, let name):
                return ["campo_id": id, "campo_name": name]
            case .campoVisited(let id, let name, let method):
                return ["campo_id": id, "campo_name": name, "method": method]
            case .campoContributionAdded(let id):
                return ["campo_id": id]
            case .achievementUnlocked(let id, let name, let xp):
                return ["achievement_id": id, "achievement_name": name, "xp": xp]
            case .levelUp(let newLevel, let totalXP):
                return ["new_level": newLevel, "total_xp": totalXP]
            case .dailyRewardClaimed(let day, let xp):
                return ["day": day, "xp": xp]
            case .screenViewed(let name):
                return ["screen_name": name]
            case .tabChanged(let to):
                return ["tab": to]
            case .error(let type, let message):
                return ["error_type": type, "message": message]
            case .apiError(let endpoint, let statusCode):
                return ["endpoint": endpoint, "status_code": statusCode]
            case .dataLoaded(let type, let count, let duration):
                return ["data_type": type, "count": count, "duration_ms": Int(duration * 1000)]
            default:
                return [:]
            }
        }
    }

    // MARK: - Initialization
    private init() {
        #if DEBUG
        self.isEnabled = true
        // En desarrollo, usar logs locales + Firebase si está disponible
        self.enabledProviders = Provider.firebase.isAvailable ? [.localLogs, .firebase] : [.localLogs]
        #else
        self.isEnabled = true
        // En producción, usar todos los proveedores disponibles
        self.enabledProviders = [.localLogs, .firebase].filter { $0.isAvailable }
        #endif

        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()

        // Configurar Firebase si está disponible
        configureFirebase()

        if isEnabled {
            let providersStr = enabledProviders.map { "\($0)" }.joined(separator: ", ")
            Logger.info("📊 Analytics inicializado con: \(providersStr) (Session: \(sessionId.prefix(8))...)")
        }
    }

    // MARK: - Firebase Configuration

    private func configureFirebase() {
        #if canImport(FirebaseAnalytics)
        guard enabledProviders.contains(.firebase) else { return }

        // Firebase ya debería estar configurado en AppDelegate
        // Aquí solo configuramos analytics-specific settings
        Analytics.setAnalyticsCollectionEnabled(true)

        // Configurar propiedades de sesión
        Analytics.setSessionTimeoutInterval(1800) // 30 minutos

        Logger.info("✅ Firebase Analytics configurado")
        #endif
    }

    // MARK: - Public Methods

    /// Registra un evento
    func track(_ event: Event) {
        guard isEnabled else { return }

        var parameters = event.parameters
        parameters["category"] = event.category.rawValue
        parameters["session_id"] = sessionId
        parameters["timestamp"] = ISO8601DateFormatter().string(from: Date())

        // Enviar a todos los proveedores habilitados
        for provider in enabledProviders {
            sendEvent(name: event.name, parameters: parameters, to: provider)
        }
    }

    /// Registra un evento personalizado
    func trackCustom(name: String, category: Category, parameters: [String: Any] = [:]) {
        guard isEnabled else { return }

        var params = parameters
        params["category"] = category.rawValue
        params["session_id"] = sessionId
        params["timestamp"] = ISO8601DateFormatter().string(from: Date())

        // Enviar a todos los proveedores habilitados
        for provider in enabledProviders {
            sendEvent(name: name, parameters: params, to: provider)
        }
    }

    /// Establece propiedades del usuario
    func setUserProperties(_ properties: [String: Any]) {
        guard isEnabled else { return }

        Logger.info("📊 User properties: \(properties)")

        // Enviar a todos los proveedores habilitados
        for provider in enabledProviders {
            sendUserProperties(properties, to: provider)
        }
    }

    /// Registra el tiempo que el usuario pasa en una pantalla
    func trackScreenTime(screen: String, duration: TimeInterval) {
        trackCustom(
            name: "screen_time",
            category: .performance,
            parameters: [
                "screen_name": screen,
                "duration_seconds": Int(duration)
            ]
        )
    }

    /// Inicia una nueva sesión
    func startNewSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        Logger.info("📊 Nueva sesión iniciada: \(sessionId.prefix(8))...")
    }

    /// Finaliza la sesión actual
    func endSession() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        trackCustom(
            name: "session_end",
            category: .performance,
            parameters: [
                "session_duration_seconds": Int(sessionDuration)
            ]
        )
    }

    // MARK: - Private Methods

    /// Envía un evento a un proveedor específico
    private func sendEvent(name: String, parameters: [String: Any], to provider: Provider) {
        switch provider {
        case .localLogs:
            logEventLocally(name: name, parameters: parameters)

        case .firebase:
            sendEventToFirebase(name: name, parameters: parameters)

        case .mixpanel:
            // TODO: Implement Mixpanel integration
            break
        }
    }

    /// Envía propiedades de usuario a un proveedor específico
    private func sendUserProperties(_ properties: [String: Any], to provider: Provider) {
        switch provider {
        case .localLogs:
            Logger.info("📊 User properties: \(properties)")

        case .firebase:
            sendUserPropertiesToFirebase(properties)

        case .mixpanel:
            // TODO: Implement Mixpanel integration
            break
        }
    }

    /// Log evento localmente (para debugging)
    private func logEventLocally(name: String, parameters: [String: Any]) {
        let paramsString = parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        Logger.debug("📊 Event: \(name) | \(paramsString)")
    }

    // MARK: - Firebase Methods

    /// Envía evento a Firebase Analytics
    private func sendEventToFirebase(name: String, parameters: [String: Any]) {
        #if canImport(FirebaseAnalytics)
        // Firebase tiene límites en los nombres y parámetros
        let sanitizedName = sanitizeFirebaseEventName(name)
        let sanitizedParams = sanitizeFirebaseParameters(parameters)

        Analytics.logEvent(sanitizedName, parameters: sanitizedParams)
        #endif
    }

    /// Envía propiedades de usuario a Firebase
    private func sendUserPropertiesToFirebase(_ properties: [String: Any]) {
        #if canImport(FirebaseAnalytics)
        for (key, value) in properties {
            let sanitizedKey = sanitizeFirebasePropertyName(key)
            let stringValue = "\(value)"
            Analytics.setUserProperty(stringValue, forName: sanitizedKey)
        }
        #endif
    }

    /// Sanitiza nombre de evento para Firebase (máx 40 caracteres, alfanumérico + _)
    private func sanitizeFirebaseEventName(_ name: String) -> String {
        let sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        return String(sanitized.prefix(40))
    }

    /// Sanitiza nombre de propiedad para Firebase
    private func sanitizeFirebasePropertyName(_ name: String) -> String {
        let sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        return String(sanitized.prefix(24)) // Firebase limit is 24 chars for property names
    }

    /// Sanitiza parámetros para Firebase
    private func sanitizeFirebaseParameters(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (key, value) in parameters {
            let sanitizedKey = sanitizeFirebasePropertyName(key)

            // Firebase solo acepta String, Int, Double como valores
            if let stringValue = value as? String {
                sanitized[sanitizedKey] = String(stringValue.prefix(100)) // Max 100 chars
            } else if let intValue = value as? Int {
                sanitized[sanitizedKey] = intValue
            } else if let doubleValue = value as? Double {
                sanitized[sanitizedKey] = doubleValue
            } else if let boolValue = value as? Bool {
                sanitized[sanitizedKey] = boolValue ? 1 : 0
            } else {
                // Convertir cualquier otro tipo a String
                sanitized[sanitizedKey] = String(describing: value).prefix(100)
            }
        }

        return sanitized
    }

    // MARK: - Helper Methods

    /// Obtiene información del dispositivo para analytics
    static func deviceInfo() -> [String: String] {
        return [
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ]
    }
}

// MARK: - Convenience Methods

extension AnalyticsManager {

    /// Track user login
    func trackLogin(method: String = "email") {
        track(.login(method: method))
    }

    /// Track user logout
    func trackLogout() {
        track(.logout)
    }

    /// Track campo view
    func trackCampoView(id: UUID, name: String) {
        track(.campoViewed(id: id.uuidString, name: name))
    }

    /// Track campo visit
    func trackCampoVisit(id: UUID, name: String, autoCheckin: Bool) {
        track(.campoVisited(
            id: id.uuidString,
            name: name,
            method: autoCheckin ? "auto" : "manual"
        ))
    }

    /// Track achievement unlock
    func trackAchievement(id: UUID, name: String, xp: Int) {
        track(.achievementUnlocked(id: id.uuidString, name: name, xp: xp))
    }

    /// Track level up
    func trackLevelUp(newLevel: Int, totalXP: Int) {
        track(.levelUp(newLevel: newLevel, totalXP: totalXP))
    }

    /// Track screen view
    func trackScreen(_ name: String) {
        track(.screenViewed(name: name))
    }

    /// Track error
    func trackError(type: String, message: String) {
        track(.error(type: type, message: message))
    }
}
