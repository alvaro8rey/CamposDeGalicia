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
    /// Requiere: mayúscula, minúscula y número
    /// - Parameter password: La contraseña a validar
    /// - Throws: ValidationError si la contraseña es débil
    static func validatePasswordStrength(_ password: String) throws {
        // Primero validar requisitos básicos
        try validatePassword(password)

        // Verificar que contenga al menos una mayúscula
        let uppercaseRegex = ".*[A-Z].*"
        let uppercasePredicate = NSPredicate(format: "SELF MATCHES %@", uppercaseRegex)
        guard uppercasePredicate.evaluate(with: password) else {
            throw ValidationError.passwordNeedsUppercase
        }

        // Verificar que contenga al menos una minúscula
        let lowercaseRegex = ".*[a-z].*"
        let lowercasePredicate = NSPredicate(format: "SELF MATCHES %@", lowercaseRegex)
        guard lowercasePredicate.evaluate(with: password) else {
            throw ValidationError.passwordNeedsLowercase
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

    // MARK: - URL Validation

    /// Valida que una URL sea válida
    /// - Parameter urlString: La URL a validar
    /// - Throws: ValidationError si la URL es inválida
    static func validateURL(_ urlString: String) throws {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty else {
            throw ValidationError.emptyURL
        }

        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https") else {
            throw ValidationError.invalidURL
        }
    }

    // MARK: - Phone Number Validation

    /// Valida que un número de teléfono tenga formato válido (español)
    /// - Parameter phone: El número de teléfono a validar
    /// - Throws: ValidationError si el teléfono es inválido
    static func validatePhoneNumber(_ phone: String) throws {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPhone.isEmpty else {
            throw ValidationError.emptyPhone
        }

        // Eliminar espacios y guiones para validar
        let digitsOnly = trimmedPhone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        // Formato español: 9 dígitos o con +34
        let phoneRegex = "^(\\+34)?[6-9][0-9]{8}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)

        guard phonePredicate.evaluate(with: digitsOnly) else {
            throw ValidationError.invalidPhone
        }
    }

    // MARK: - Number Validation

    /// Valida que un string sea un número entero válido dentro de un rango
    /// - Parameters:
    ///   - text: El texto a validar
    ///   - min: Valor mínimo permitido (opcional)
    ///   - max: Valor máximo permitido (opcional)
    /// - Throws: ValidationError si no es un número válido o está fuera de rango
    static func validateInteger(_ text: String, min: Int? = nil, max: Int? = nil) throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw ValidationError.emptyNumber
        }

        guard let number = Int(trimmedText) else {
            throw ValidationError.invalidNumber
        }

        if let min = min, number < min {
            throw ValidationError.numberTooSmall(min)
        }

        if let max = max, number > max {
            throw ValidationError.numberTooLarge(max)
        }
    }

    /// Valida que un string sea un número decimal válido dentro de un rango
    /// - Parameters:
    ///   - text: El texto a validar
    ///   - min: Valor mínimo permitido (opcional)
    ///   - max: Valor máximo permitido (opcional)
    /// - Throws: ValidationError si no es un número válido o está fuera de rango
    static func validateDecimal(_ text: String, min: Double? = nil, max: Double? = nil) throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw ValidationError.emptyNumber
        }

        guard let number = Double(trimmedText) else {
            throw ValidationError.invalidNumber
        }

        if let min = min, number < min {
            throw ValidationError.numberTooSmall(Int(min))
        }

        if let max = max, number > max {
            throw ValidationError.numberTooLarge(Int(max))
        }
    }

    // MARK: - Text Length Validation

    /// Valida que un texto tenga una longitud dentro de un rango
    /// - Parameters:
    ///   - text: El texto a validar
    ///   - min: Longitud mínima (default: 1)
    ///   - max: Longitud máxima (default: 1000)
    ///   - fieldName: Nombre del campo para mensajes de error
    /// - Throws: ValidationError si la longitud es inválida
    static func validateTextLength(_ text: String, min: Int = 1, max: Int = 1000, fieldName: String = "texto") throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw ValidationError.emptyField(fieldName)
        }

        guard trimmedText.count >= min else {
            throw ValidationError.textTooShort(fieldName, min)
        }

        guard trimmedText.count <= max else {
            throw ValidationError.textTooLong(fieldName, max)
        }
    }

    // MARK: - Postal Code Validation

    /// Valida que un código postal español sea válido
    /// - Parameter postalCode: El código postal a validar
    /// - Throws: ValidationError si el código postal es inválido
    static func validatePostalCode(_ postalCode: String) throws {
        let trimmedCode = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCode.isEmpty else {
            throw ValidationError.emptyPostalCode
        }

        // Código postal español: 5 dígitos del 01000 al 52999
        let postalRegex = "^(0[1-9]|[1-4][0-9]|5[0-2])[0-9]{3}$"
        let postalPredicate = NSPredicate(format: "SELF MATCHES %@", postalRegex)

        guard postalPredicate.evaluate(with: trimmedCode) else {
            throw ValidationError.invalidPostalCode
        }
    }

    // MARK: - Image Validation

    /// Valida que el tamaño de una imagen sea apropiado
    /// - Parameters:
    ///   - data: Los datos de la imagen
    ///   - maxSizeInMB: Tamaño máximo en MB (default: 5)
    /// - Throws: ValidationError si la imagen es demasiado grande
    static func validateImageSize(_ data: Data, maxSizeInMB: Double = 5.0) throws {
        let sizeInMB = Double(data.count) / (1024.0 * 1024.0)

        guard sizeInMB <= maxSizeInMB else {
            throw ValidationError.imageTooLarge(maxSizeInMB)
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    // Email
    case emptyEmail
    case invalidEmailFormat

    // Password
    case emptyPassword
    case passwordTooShort
    case passwordTooLong
    case passwordNeedsLetter
    case passwordNeedsUppercase
    case passwordNeedsLowercase
    case passwordNeedsNumber

    // Name
    case emptyName
    case nameTooShort
    case nameTooLong

    // URL
    case emptyURL
    case invalidURL

    // Phone
    case emptyPhone
    case invalidPhone

    // Number
    case emptyNumber
    case invalidNumber
    case numberTooSmall(Int)
    case numberTooLarge(Int)

    // Text
    case emptyField(String)
    case textTooShort(String, Int)
    case textTooLong(String, Int)

    // Postal Code
    case emptyPostalCode
    case invalidPostalCode

    // Image
    case imageTooLarge(Double)

    var errorDescription: String? {
        switch self {
        // Email
        case .emptyEmail:
            return "El email no puede estar vacío"
        case .invalidEmailFormat:
            return "El formato del email no es válido"

        // Password
        case .emptyPassword:
            return "La contraseña no puede estar vacía"
        case .passwordTooShort:
            return "La contraseña debe tener al menos 8 caracteres"
        case .passwordTooLong:
            return "La contraseña no puede tener más de 128 caracteres"
        case .passwordNeedsLetter:
            return "La contraseña debe contener al menos una letra"
        case .passwordNeedsUppercase:
            return "La contraseña debe contener al menos una mayúscula"
        case .passwordNeedsLowercase:
            return "La contraseña debe contener al menos una minúscula"
        case .passwordNeedsNumber:
            return "La contraseña debe contener al menos un número"

        // Name
        case .emptyName:
            return "El nombre no puede estar vacío"
        case .nameTooShort:
            return "El nombre debe tener al menos 2 caracteres"
        case .nameTooLong:
            return "El nombre no puede tener más de 50 caracteres"

        // URL
        case .emptyURL:
            return "La URL no puede estar vacía"
        case .invalidURL:
            return "La URL no es válida"

        // Phone
        case .emptyPhone:
            return "El número de teléfono no puede estar vacío"
        case .invalidPhone:
            return "El número de teléfono no es válido"

        // Number
        case .emptyNumber:
            return "El número no puede estar vacío"
        case .invalidNumber:
            return "El valor debe ser un número válido"
        case .numberTooSmall(let min):
            return "El número debe ser al menos \(min)"
        case .numberTooLarge(let max):
            return "El número no puede ser mayor que \(max)"

        // Text
        case .emptyField(let fieldName):
            return "El campo '\(fieldName)' no puede estar vacío"
        case .textTooShort(let fieldName, let min):
            return "'\(fieldName)' debe tener al menos \(min) caracteres"
        case .textTooLong(let fieldName, let max):
            return "'\(fieldName)' no puede tener más de \(max) caracteres"

        // Postal Code
        case .emptyPostalCode:
            return "El código postal no puede estar vacío"
        case .invalidPostalCode:
            return "El código postal no es válido"

        // Image
        case .imageTooLarge(let maxSizeInMB):
            return "La imagen es demasiado grande (máximo \(String(format: "%.1f", maxSizeInMB)) MB)"
        }
    }
}
