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

        let authResp = try await supabase.auth.signUp(email: email, password: password)
        let userId = authResp.user.id.uuidString

        // Crear perfil
        let perfil = Perfil(id: userId, nombre: nombre, apellidos: apellidos, isAdmin: false)
        try await supabase.from("perfiles").insert(perfil).execute()

        Logger.success("✅ Registro exitoso para: \(email)")
        AnalyticsManager.shared.track(.register)

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

        Logger.info("✅ Sesión cerrada")
        AnalyticsManager.shared.trackLogout()
    }

    /// Solicitar reset de contraseña
    func requestPasswordReset(email: String) async throws {
        Logger.debug("Solicitando reset de contraseña para: \(email)")
        try await supabase.auth.resetPasswordForEmail(email)
        Logger.success("✅ Email de reset enviado")
    }

    /// Cambiar contraseña
    func changePassword(newPassword: String) async throws {
        Logger.debug("Cambiando contraseña")
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
            .select("nombre, apellidos")
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()

        let jsonObject = try JSONSerialization.jsonObject(with: perfilResponse.data, options: [])
        if let dict = jsonObject as? [String: Any] {
            self.nombre = dict["nombre"] as? String ?? ""
            self.apellidos = dict["apellidos"] as? String ?? ""
            Logger.debug("Perfil cargado: \(self.nombre) \(self.apellidos)")
        }
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
}
