import Foundation
import SwiftUI
import Supabase

/// ViewModel compartido para autenticación y estado del usuario
@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var user: User? = nil
    @Published var nombre: String = ""
    @Published var apellidos: String = ""
    @Published var avatarURL: String? = nil

    // MARK: - Singleton
    static let shared = AuthViewModel()

    private init() {
        Logger.debug("AuthViewModel inicializado")
        checkCurrentSession()
    }

    // MARK: - Methods

    /// Verifica si hay una sesión activa
    func checkCurrentSession() {
        if let currentUser = supabase.auth.currentUser {
            self.user = currentUser
            self.isAuthenticated = true
            Logger.info("✅ Sesión activa encontrada para: \(currentUser.email ?? "unknown")")
            AnalyticsManager.shared.setUserProperties([
                "user_id": currentUser.id.uuidString,
                "email": currentUser.email ?? ""
            ])
        } else {
            Logger.debug("No hay sesión activa")
        }
    }

    /// Login de usuario
    func login(email: String, password: String) async throws {
        Logger.debug("Intentando login para: \(email)")

        // Validar inputs antes de enviar a Supabase
        try InputValidator.validateEmail(email)
        try InputValidator.validatePassword(password)

        let session = try await supabase.auth.signIn(email: email, password: password)
        self.user = session.user
        self.isAuthenticated = true

        Logger.success("✅ Login exitoso para: \(email)")
        AnalyticsManager.shared.trackLogin()
        AnalyticsManager.shared.setUserProperties([
            "user_id": session.user.id.uuidString,
            "email": email
        ])
    }

    /// Registro de usuario
    func register(email: String, password: String, nombre: String, apellidos: String) async throws -> String {
        Logger.debug("Intentando registro para: \(email)")

        // Validar inputs antes de enviar a Supabase
        try InputValidator.validateEmail(email)
        try InputValidator.validatePasswordStrength(password) // Validación más estricta para registro
        try InputValidator.validateName(nombre)
        try InputValidator.validateName(apellidos)

        let authResp = try await supabase.auth.signUp(email: email, password: password)
        let userId = authResp.user.id.uuidString

        // Crear perfil
        let perfil = Perfil(id: userId, nombre: nombre, apellidos: apellidos, isAdmin: false)
        try await supabase.from("perfiles").insert(perfil).execute()

        // Auto-login: establecer estado autenticado
        self.user = authResp.user
        self.isAuthenticated = true
        self.nombre = nombre
        self.apellidos = apellidos

        Logger.success("✅ Registro exitoso para: \(email)")
        AnalyticsManager.shared.track(.register)
        AnalyticsManager.shared.setUserProperties([
            "user_id": userId,
            "email": email
        ])

        // Cargar datos iniciales de progreso
        await ProgressStore.shared.loadInitialData(for: userId)

        return userId
    }

    /// Logout
    func logout() async throws {
        Logger.debug("Cerrando sesión")

        try await supabase.auth.signOut()
        self.isAuthenticated = false
        self.user = nil
        self.nombre = ""
        self.apellidos = ""
        self.avatarURL = nil

        Logger.info("✅ Sesión cerrada")
        AnalyticsManager.shared.trackLogout()
    }

    /// Solicitar reset de contraseña
    func requestPasswordReset(email: String) async throws {
        Logger.debug("Solicitando reset de contraseña para: \(email)")

        // Validar email antes de enviar
        try InputValidator.validateEmail(email)

        try await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "camposdegalicia://reset-callback")
        )
        Logger.success("✅ Email de reset enviado")
    }

    /// Cambiar contraseña
    func changePassword(newPassword: String) async throws {
        Logger.debug("Cambiando contraseña")

        // Validar la nueva contraseña
        try InputValidator.validatePasswordStrength(newPassword)

        try await supabase.auth.update(user: UserAttributes(password: newPassword))
        Logger.success("✅ Contraseña actualizada")
    }

    /// Cargar datos del perfil
    func loadProfileData() async throws {
        guard let user = user else {
            throw NSError(domain: "AuthViewModel", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Usuario no autenticado"
            ])
        }

        let perfilResponse = try await supabase.from("perfiles")
            .select("nombre, apellidos, avatar_url")
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()

        // Usar Codable para parsear la respuesta de forma type-safe
        struct PerfilData: Codable {
            let nombre: String?
            let apellidos: String?
            let avatar_url: String?
        }

        let decoder = JSONDecoder()
        let perfilData = try decoder.decode(PerfilData.self, from: perfilResponse.data)

        self.nombre = perfilData.nombre ?? ""
        self.apellidos = perfilData.apellidos ?? ""
        self.avatarURL = perfilData.avatar_url
        Logger.debug("Perfil cargado: \(self.nombre) \(self.apellidos)")

        // Cargar datos iniciales en ProgressStore
        await ProgressStore.shared.loadInitialData(for: user.id.uuidString)
    }

    /// Guardar cambios del perfil
    func saveProfileChanges(nombre: String, apellidos: String) async throws {
        guard let user = user else {
            throw NSError(domain: "AuthViewModel", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Usuario no autenticado"
            ])
        }

        guard !nombre.isEmpty, !apellidos.isEmpty else {
            throw NSError(domain: "AuthViewModel", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Nombre y apellidos no pueden estar vacíos"
            ])
        }

        let updatedPerfil: [String: String] = ["nombre": nombre, "apellidos": apellidos]
        _ = try await supabase.from("perfiles")
            .update(updatedPerfil)
            .eq("id", value: user.id.uuidString)
            .execute()

        self.nombre = nombre
        self.apellidos = apellidos

        Logger.success("✅ Perfil actualizado")
        AnalyticsManager.shared.track(.profileUpdate)
    }

    /// Subir foto de perfil
    func uploadProfilePhoto(imageData: Data) async throws -> String {
        guard let user = user else {
            throw NSError(domain: "AuthViewModel", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Usuario no autenticado"
            ])
        }

        let fileName = "\(user.id.uuidString)_\(Date().timeIntervalSince1970).jpg"
        let filePath = "avatars/\(fileName)"

        // Subir imagen a Supabase Storage
        _ = try await supabase.storage
            .from("profile-photos")
            .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))

        // Obtener URL pública
        let publicURL = try supabase.storage
            .from("profile-photos")
            .getPublicURL(path: filePath)

        // Actualizar perfil con la URL
        let updatedPerfil: [String: String] = ["avatar_url": publicURL.absoluteString]
        _ = try await supabase.from("perfiles")
            .update(updatedPerfil)
            .eq("id", value: user.id.uuidString)
            .execute()

        self.avatarURL = publicURL.absoluteString

        Logger.success("✅ Foto de perfil actualizada")
        return publicURL.absoluteString
    }

    /// Eliminar foto de perfil
    func deleteProfilePhoto() async throws {
        guard let user = user else {
            throw NSError(domain: "AuthViewModel", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Usuario no autenticado"
            ])
        }

        // Actualizar perfil para remover la URL
        struct AvatarUpdate: Encodable {
            let avatar_url: String?
        }

        let update = AvatarUpdate(avatar_url: nil)
        _ = try await supabase.from("perfiles")
            .update(update)
            .eq("id", value: user.id.uuidString)
            .execute()

        self.avatarURL = nil

        Logger.success("✅ Foto de perfil eliminada")
    }
}
