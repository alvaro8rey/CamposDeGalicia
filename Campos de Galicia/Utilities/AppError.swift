import Foundation

/// Errores centralizados de la aplicación
/// Proporciona categorización, mensajes localizados y sugerencias de recuperación
enum AppError: LocalizedError {

    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkError(Error)

    // MARK: - Database Errors
    case databaseConnectionFailed
    case databaseQueryFailed(String)
    case databaseInsertFailed
    case databaseUpdateFailed
    case databaseDeleteFailed
    case recordNotFound
    case duplicateRecord

    // MARK: - Authentication Errors
    case notAuthenticated
    case invalidCredentials
    case sessionExpired
    case userNotFound
    case emailAlreadyInUse
    case weakPassword

    // MARK: - Validation Errors
    case validation(ValidationError)
    case invalidInput(String)
    case missingRequiredField(String)

    // MARK: - Storage Errors
    case storageUploadFailed
    case storageDownloadFailed
    case storageDeleteFailed
    case fileNotFound
    case fileTooLarge

    // MARK: - Permission Errors
    case locationPermissionDenied
    case notificationPermissionDenied
    case cameraPermissionDenied
    case photoLibraryPermissionDenied

    // MARK: - Configuration Errors
    case config(AppConfigError)

    // MARK: - Business Logic Errors
    case invalidOperation(String)
    case operationNotAllowed(String)
    case insufficientData

    // MARK: - Unknown Errors
    case unknown(Error)

    // MARK: - Error Category

    var category: ErrorCategory {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkError:
            return .network
        case .databaseConnectionFailed, .databaseQueryFailed, .databaseInsertFailed,
             .databaseUpdateFailed, .databaseDeleteFailed, .recordNotFound, .duplicateRecord:
            return .database
        case .notAuthenticated, .invalidCredentials, .sessionExpired, .userNotFound,
             .emailAlreadyInUse, .weakPassword:
            return .authentication
        case .validation, .invalidInput, .missingRequiredField:
            return .validation
        case .storageUploadFailed, .storageDownloadFailed, .storageDeleteFailed,
             .fileNotFound, .fileTooLarge:
            return .storage
        case .locationPermissionDenied, .notificationPermissionDenied,
             .cameraPermissionDenied, .photoLibraryPermissionDenied:
            return .permission
        case .config:
            return .configuration
        case .invalidOperation, .operationNotAllowed, .insufficientData:
            return .businessLogic
        case .unknown:
            return .unknown
        }
    }

    // MARK: - Error Description

    var errorDescription: String? {
        switch self {
        // Network Errors
        case .networkUnavailable:
            return "No hay conexión a internet. Verifica tu conexión e inténtalo de nuevo."
        case .networkTimeout:
            return "La operación tardó demasiado tiempo. Inténtalo de nuevo."
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"

        // Database Errors
        case .databaseConnectionFailed:
            return "No se pudo conectar a la base de datos. Inténtalo más tarde."
        case .databaseQueryFailed(let details):
            return "Error al consultar datos: \(details)"
        case .databaseInsertFailed:
            return "Error al guardar los datos. Inténtalo de nuevo."
        case .databaseUpdateFailed:
            return "Error al actualizar los datos. Inténtalo de nuevo."
        case .databaseDeleteFailed:
            return "Error al eliminar los datos. Inténtalo de nuevo."
        case .recordNotFound:
            return "No se encontró el registro solicitado."
        case .duplicateRecord:
            return "Este registro ya existe."

        // Authentication Errors
        case .notAuthenticated:
            return "Debes iniciar sesión para realizar esta acción."
        case .invalidCredentials:
            return "Email o contraseña incorrectos."
        case .sessionExpired:
            return "Tu sesión ha expirado. Por favor, inicia sesión de nuevo."
        case .userNotFound:
            return "No se encontró ningún usuario con ese email."
        case .emailAlreadyInUse:
            return "Este email ya está registrado."
        case .weakPassword:
            return "La contraseña es demasiado débil."

        // Validation Errors
        case .validation(let error):
            return error.errorDescription
        case .invalidInput(let field):
            return "El valor de '\(field)' no es válido."
        case .missingRequiredField(let field):
            return "El campo '\(field)' es obligatorio."

        // Storage Errors
        case .storageUploadFailed:
            return "Error al subir el archivo. Inténtalo de nuevo."
        case .storageDownloadFailed:
            return "Error al descargar el archivo."
        case .storageDeleteFailed:
            return "Error al eliminar el archivo."
        case .fileNotFound:
            return "No se encontró el archivo."
        case .fileTooLarge:
            return "El archivo es demasiado grande."

        // Permission Errors
        case .locationPermissionDenied:
            return "Necesitas activar los permisos de ubicación en Ajustes."
        case .notificationPermissionDenied:
            return "Necesitas activar los permisos de notificaciones en Ajustes."
        case .cameraPermissionDenied:
            return "Necesitas activar los permisos de cámara en Ajustes."
        case .photoLibraryPermissionDenied:
            return "Necesitas activar los permisos de fotos en Ajustes."

        // Configuration Errors
        case .config(let error):
            return error.errorDescription

        // Business Logic Errors
        case .invalidOperation(let message):
            return message
        case .operationNotAllowed(let reason):
            return "Operación no permitida: \(reason)"
        case .insufficientData:
            return "No hay suficientes datos para completar la operación."

        // Unknown Errors
        case .unknown(let error):
            return "Error inesperado: \(error.localizedDescription)"
        }
    }

    // MARK: - Recovery Suggestion

    var recoverySuggestion: String? {
        switch self {
        // Network Errors
        case .networkUnavailable:
            return "Activa tu Wi-Fi o datos móviles e inténtalo de nuevo."
        case .networkTimeout:
            return "Verifica tu conexión a internet e inténtalo de nuevo."
        case .networkError:
            return "Verifica tu conexión a internet."

        // Database Errors
        case .databaseConnectionFailed:
            return "Espera unos momentos e inténtalo de nuevo."
        case .databaseQueryFailed, .databaseInsertFailed, .databaseUpdateFailed, .databaseDeleteFailed:
            return "Inténtalo de nuevo. Si el problema persiste, contacta con soporte."
        case .recordNotFound:
            return "El registro puede haber sido eliminado."
        case .duplicateRecord:
            return "Ya existe un registro con esos datos."

        // Authentication Errors
        case .notAuthenticated:
            return "Inicia sesión para continuar."
        case .invalidCredentials:
            return "Verifica tu email y contraseña."
        case .sessionExpired:
            return "Vuelve a iniciar sesión."
        case .userNotFound:
            return "Verifica que el email sea correcto o regístrate."
        case .emailAlreadyInUse:
            return "Usa otro email o inicia sesión."
        case .weakPassword:
            return "Usa al menos 8 caracteres con letras y números."

        // Validation Errors
        case .validation:
            return "Corrige los errores e inténtalo de nuevo."
        case .invalidInput, .missingRequiredField:
            return "Verifica que todos los campos sean correctos."

        // Storage Errors
        case .storageUploadFailed, .storageDownloadFailed, .storageDeleteFailed:
            return "Verifica tu conexión e inténtalo de nuevo."
        case .fileNotFound:
            return "El archivo puede haber sido eliminado."
        case .fileTooLarge:
            return "Usa un archivo más pequeño (máximo 5 MB)."

        // Permission Errors
        case .locationPermissionDenied, .notificationPermissionDenied,
             .cameraPermissionDenied, .photoLibraryPermissionDenied:
            return "Ve a Ajustes > Campos de Galicia y activa los permisos."

        // Configuration Errors
        case .config(let error):
            return error.recoverySuggestion

        // Business Logic Errors
        case .invalidOperation, .operationNotAllowed:
            return "Verifica que la operación sea válida."
        case .insufficientData:
            return "Completa todos los datos necesarios."

        // Unknown Errors
        case .unknown:
            return "Si el problema persiste, contacta con soporte."
        }
    }

    // MARK: - Is Recoverable

    /// Indica si el error es recuperable (el usuario puede reintentar)
    var isRecoverable: Bool {
        switch self {
        case .networkTimeout, .networkError, .databaseConnectionFailed,
             .databaseQueryFailed, .databaseInsertFailed, .databaseUpdateFailed,
             .storageUploadFailed, .storageDownloadFailed:
            return true
        case .notAuthenticated, .sessionExpired, .validation, .invalidInput,
             .missingRequiredField, .fileTooLarge:
            return true
        case .invalidCredentials, .userNotFound, .emailAlreadyInUse,
             .recordNotFound, .duplicateRecord, .fileNotFound:
            return false
        default:
            return false
        }
    }

    // MARK: - Should Log

    /// Indica si el error debe ser registrado en analytics
    var shouldLog: Bool {
        switch self {
        case .validation, .invalidInput, .missingRequiredField:
            return false // Errores de validación son normales, no los registramos
        case .invalidCredentials, .userNotFound:
            return false // Errores de login esperados
        default:
            return true
        }
    }
}

// MARK: - Error Category

enum ErrorCategory: String {
    case network
    case database
    case authentication
    case validation
    case storage
    case permission
    case configuration
    case businessLogic
    case unknown

    var icon: String {
        switch self {
        case .network:
            return "wifi.slash"
        case .database:
            return "externaldrive.badge.xmark"
        case .authentication:
            return "person.crop.circle.badge.xmark"
        case .validation:
            return "exclamationmark.triangle"
        case .storage:
            return "folder.badge.questionmark"
        case .permission:
            return "lock.shield"
        case .configuration:
            return "gearshape.2"
        case .businessLogic:
            return "exclamationmark.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Error Conversion Extensions

extension AppError {
    /// Convierte errores comunes de Supabase en AppError
    static func from(supabaseError error: Error) -> AppError {
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("network") || errorDescription.contains("timeout") {
            return .networkError(error)
        } else if errorDescription.contains("duplicate") {
            return .duplicateRecord
        } else if errorDescription.contains("not found") {
            return .recordNotFound
        } else if errorDescription.contains("unauthorized") || errorDescription.contains("invalid token") {
            return .sessionExpired
        } else if errorDescription.contains("invalid credentials") {
            return .invalidCredentials
        } else {
            return .unknown(error)
        }
    }

    /// Convierte NSError en AppError
    static func from(nsError error: NSError) -> AppError {
        switch error.domain {
        case NSURLErrorDomain:
            if error.code == NSURLErrorNotConnectedToInternet {
                return .networkUnavailable
            } else if error.code == NSURLErrorTimedOut {
                return .networkTimeout
            }
            return .networkError(error)
        default:
            return .unknown(error)
        }
    }
}
