import Foundation

/// Utilidades para validar inputs de usuario
enum InputValidator {

    // MARK: - Email Validation

    /// Valida que un email tenga formato correcto
    /// - Parameter email: El email a validar
    /// - Throws: ValidationError si el email es inválido
    static func validateEmail(_ email: String) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // Verificar que no esté vacío
        guard !trimmedEmail.isEmpty else {
            throw ValidationError.emptyEmail
        }

        // Verificar formato usando regex
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: trimmedEmail) else {
            throw ValidationError.invalidEmailFormat
        }
    }

    // MARK: - Password Validation

    /// Valida que una contraseña cumpla con los requisitos mínimos
    /// - Parameter password: La contraseña a validar
    /// - Throws: ValidationError si la contraseña es inválida
    static func validatePassword(_ password: String) throws {
        // Verificar que no esté vacía
        guard !password.isEmpty else {
            throw ValidationError.emptyPassword
        }

        // Verificar longitud mínima (8 caracteres es estándar)
        guard password.count >= 8 else {
            throw ValidationError.passwordTooShort
        }

        // Verificar longitud máxima (para prevenir ataques DoS)
        guard password.count <= 128 else {
            throw ValidationError.passwordTooLong
        }
    }

    /// Valida la fortaleza de una contraseña (para registro)
    /// - Parameter password: La contraseña a validar
    /// - Throws: ValidationError si la contraseña es débil
    static func validatePasswordStrength(_ password: String) throws {
        // Primero validar requisitos básicos
        try validatePassword(password)

        // Verificar que contenga al menos una letra
        let letterRegex = ".*[A-Za-z].*"
        let letterPredicate = NSPredicate(format: "SELF MATCHES %@", letterRegex)
        guard letterPredicate.evaluate(with: password) else {
            throw ValidationError.passwordNeedsLetter
        }

        // Verificar que contenga al menos un número
        let numberRegex = ".*[0-9].*"
        let numberPredicate = NSPredicate(format: "SELF MATCHES %@", numberRegex)
        guard numberPredicate.evaluate(with: password) else {
            throw ValidationError.passwordNeedsNumber
        }
    }

    // MARK: - Name Validation

    /// Valida que un nombre no esté vacío y tenga longitud razonable
    /// - Parameter name: El nombre a validar
    /// - Throws: ValidationError si el nombre es inválido
    static func validateName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        guard trimmedName.count >= 2 else {
            throw ValidationError.nameTooShort
        }

        guard trimmedName.count <= 50 else {
            throw ValidationError.nameTooLong
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case emptyEmail
    case invalidEmailFormat
    case emptyPassword
    case passwordTooShort
    case passwordTooLong
    case passwordNeedsLetter
    case passwordNeedsNumber
    case emptyName
    case nameTooShort
    case nameTooLong

    var errorDescription: String? {
        switch self {
        case .emptyEmail:
            return "El email no puede estar vacío"
        case .invalidEmailFormat:
            return "El formato del email no es válido"
        case .emptyPassword:
            return "La contraseña no puede estar vacía"
        case .passwordTooShort:
            return "La contraseña debe tener al menos 8 caracteres"
        case .passwordTooLong:
            return "La contraseña no puede tener más de 128 caracteres"
        case .passwordNeedsLetter:
            return "La contraseña debe contener al menos una letra"
        case .passwordNeedsNumber:
            return "La contraseña debe contener al menos un número"
        case .emptyName:
            return "El nombre no puede estar vacío"
        case .nameTooShort:
            return "El nombre debe tener al menos 2 caracteres"
        case .nameTooLong:
            return "El nombre no puede tener más de 50 caracteres"
        }
    }
}
