import Foundation
import SwiftUI

/// Manager centralizado para manejo de errores
/// Proporciona manejo consistente, logging y presentación de errores en toda la app
@MainActor
class ErrorHandler: ObservableObject {

    // MARK: - Singleton
    static let shared = ErrorHandler()

    // MARK: - Published Properties
    @Published var lastError: AppError?
    @Published var errorCount: Int = 0

    // MARK: - Private Properties
    private var errorHistory: [ErrorRecord] = []
    private let maxErrorHistory = 50

    // MARK: - Initialization
    private init() {
        Logger.debug("ErrorHandler inicializado")
    }

    // MARK: - Main Error Handling

    /// Maneja un error de manera centralizada
    /// - Parameters:
    ///   - error: El error a manejar
    ///   - showToUser: Si debe mostrarse un toast al usuario (default: true)
    ///   - context: Contexto adicional para debugging (opcional)
    func handle(_ error: Error, showToUser: Bool = true, context: String? = nil) {
        let appError = convertToAppError(error)
        handle(appError, showToUser: showToUser, context: context)
    }

    /// Maneja un AppError de manera centralizada
    /// - Parameters:
    ///   - error: El AppError a manejar
    ///   - showToUser: Si debe mostrarse un toast al usuario (default: true)
    ///   - context: Contexto adicional para debugging (opcional)
    func handle(_ error: AppError, showToUser: Bool = true, context: String? = nil) {
        // Actualizar estado
        lastError = error
        errorCount += 1

        // Guardar en historial
        recordError(error, context: context)

        // Log del error
        logError(error, context: context)

        // Trackear en analytics si es necesario
        if error.shouldLog {
            trackError(error, context: context)
        }

        // Mostrar al usuario si es necesario
        if showToUser {
            showErrorToUser(error)
        }
    }

    // MARK: - Error Conversion

    /// Convierte cualquier Error en AppError
    private func convertToAppError(_ error: Error) -> AppError {
        // Si ya es un AppError, retornarlo
        if let appError = error as? AppError {
            return appError
        }

        // Si es ValidationError, convertirlo
        if let validationError = error as? ValidationError {
            return .validation(validationError)
        }

        // Si es AppConfigError, convertirlo
        if let configError = error as? AppConfigError {
            return .config(configError)
        }

        // Si es NSError, usar conversión especializada
        if let nsError = error as NSError? {
            return AppError.from(nsError: nsError)
        }

        // Verificar si es un error de Supabase común
        return AppError.from(supabaseError: error)
    }

    // MARK: - User Presentation

    /// Muestra el error al usuario mediante toast
    private func showErrorToUser(_ error: AppError) {
        let message = error.errorDescription ?? "Error desconocido"

        // Usar diferentes duraciones según la severidad
        let duration: Double = error.isRecoverable ? 4.0 : 5.0

        ToastManager.shared.error(message, duration: duration)

        // Si hay sugerencia de recuperación, mostrarla en un segundo toast
        if let suggestion = error.recoverySuggestion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ToastManager.shared.info(suggestion, duration: 4.0)
            }
        }
    }

    // MARK: - Logging

    /// Registra el error en el sistema de logging
    private func logError(_ error: AppError, context: String?) {
        let contextString = context.map { " [Context: \($0)]" } ?? ""
        let errorMessage = error.errorDescription ?? "Error desconocido"
        let category = error.category.rawValue

        Logger.error("[\(category.uppercased())] \(errorMessage)\(contextString)")

        // Log adicional para errores críticos
        if !error.isRecoverable {
            Logger.error("⚠️ Error no recuperable detectado")
        }
    }

    // MARK: - Analytics Tracking

    /// Trackea el error en analytics
    private func trackError(_ error: AppError, context: String?) {
        var parameters: [String: Any] = [
            "error_category": error.category.rawValue,
            "error_description": error.errorDescription ?? "unknown",
            "is_recoverable": error.isRecoverable,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let context = context {
            parameters["context"] = context
        }

        // Trackear en analytics
        AnalyticsManager.shared.trackCustom(
            name: "error_occurred",
            category: .error,
            parameters: parameters
        )
    }

    // MARK: - Error History

    /// Registra el error en el historial
    private func recordError(_ error: AppError, context: String?) {
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date()
        )

        errorHistory.append(record)

        // Mantener solo los últimos N errores
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst()
        }
    }

    /// Obtiene el historial de errores recientes
    func getRecentErrors(limit: Int = 10) -> [ErrorRecord] {
        return Array(errorHistory.suffix(limit))
    }

    /// Limpia el historial de errores
    func clearErrorHistory() {
        errorHistory.removeAll()
        errorCount = 0
        lastError = nil
        Logger.info("Historial de errores limpiado")
    }

    // MARK: - Network-Specific Handling

    /// Maneja errores de red con lógica específica
    func handleNetworkError(_ error: Error, context: String? = nil) {
        // Verificar estado de red actual
        let isConnected = NetworkMonitor.shared.isConnected

        if !isConnected {
            handle(.networkUnavailable, context: context)
        } else {
            handle(error, context: context)
        }
    }

    // MARK: - Database-Specific Handling

    /// Maneja errores de base de datos con lógica específica
    func handleDatabaseError(_ error: Error, operation: DatabaseOperation, context: String? = nil) {
        let appError: AppError

        switch operation {
        case .query:
            appError = .databaseQueryFailed(error.localizedDescription)
        case .insert:
            appError = .databaseInsertFailed
        case .update:
            appError = .databaseUpdateFailed
        case .delete:
            appError = .databaseDeleteFailed
        }

        handle(appError, context: context)
    }

    // MARK: - Validation Handling

    /// Maneja errores de validación (no los muestra en toast por defecto)
    func handleValidationError(_ error: ValidationError, showToUser: Bool = false) {
        handle(.validation(error), showToUser: showToUser)
    }

    // MARK: - Retry Logic

    /// Ejecuta una operación con retry automático en caso de errores recuperables
    /// - Parameters:
    ///   - maxRetries: Número máximo de reintentos (default: 3)
    ///   - delay: Delay entre reintentos en segundos (default: 1.0)
    ///   - operation: Operación async a ejecutar
    /// - Returns: Resultado de la operación
    func withRetry<T>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt < maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                let appError = convertToAppError(error)

                // Solo reintentar si el error es recuperable
                guard appError.isRecoverable else {
                    throw error
                }

                attempt += 1

                if attempt < maxRetries {
                    Logger.warning("⚠️ Reintentando operación (intento \(attempt + 1)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // Si llegamos aquí, todos los reintentos fallaron
        if let error = lastError {
            handle(error, context: "after \(maxRetries) retries")
            throw error
        }

        throw AppError.unknown(NSError(domain: "ErrorHandler", code: -1))
    }

    // MARK: - Error Statistics

    /// Obtiene estadísticas de errores
    func getErrorStatistics() -> ErrorStatistics {
        let categoryCount = Dictionary(grouping: errorHistory, by: { $0.error.category })
            .mapValues { $0.count }

        let recoverableCount = errorHistory.filter { $0.error.isRecoverable }.count
        let criticalCount = errorHistory.filter { !$0.error.isRecoverable }.count

        return ErrorStatistics(
            totalErrors: errorHistory.count,
            categoryCounts: categoryCount,
            recoverableErrors: recoverableCount,
            criticalErrors: criticalCount
        )
    }
}

// MARK: - Supporting Types

/// Registro de un error en el historial
struct ErrorRecord: Identifiable {
    let id = UUID()
    let error: AppError
    let context: String?
    let timestamp: Date
}

/// Operaciones de base de datos
enum DatabaseOperation {
    case query
    case insert
    case update
    case delete
}

/// Estadísticas de errores
struct ErrorStatistics {
    let totalErrors: Int
    let categoryCounts: [ErrorCategory: Int]
    let recoverableErrors: Int
    let criticalErrors: Int
}

// MARK: - Convenience Extensions

extension View {
    /// Maneja errores de manera automática en la vista
    func handleErrors() -> some View {
        self.environmentObject(ErrorHandler.shared)
    }
}

// MARK: - Global Error Handling Helpers

/// Helper global para manejar errores de manera concisa
func handleError(_ error: Error, context: String? = nil) {
    Task { @MainActor in
        ErrorHandler.shared.handle(error, context: context)
    }
}

/// Helper global para manejar errores sin mostrarlos al usuario
func logError(_ error: Error, context: String? = nil) {
    Task { @MainActor in
        ErrorHandler.shared.handle(error, showToUser: false, context: context)
    }
}
