import SwiftUI
import Supabase

/// Vista modal para editar el perfil completo del usuario
struct EditProfileView: View {

    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - State
    @State private var nombre: String
    @State private var apellidos: String
    @State private var email: String
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showPasswordFields: Bool = false
    @State private var showEmailChangeConfirmation: Bool = false

    // MARK: - Initialization
    init(nombre: String, apellidos: String, email: String) {
        _nombre = State(initialValue: nombre)
        _apellidos = State(initialValue: apellidos)
        _email = State(initialValue: email)
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Personal Info Section
                Section {
                    TextField("Nombre", text: $nombre)
                        .textContentType(.givenName)
                        .autocapitalization(.words)

                    TextField("Apellidos", text: $apellidos)
                        .textContentType(.familyName)
                        .autocapitalization(.words)
                } header: {
                    Label("Información Personal", systemImage: "person.fill")
                }

                // MARK: - Email Section
                Section {
                    HStack {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(true) // Por defecto deshabilitado
                            .opacity(0.7)

                        if email != authViewModel.user?.email ?? "" {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    if email != authViewModel.user?.email ?? "" {
                        Text("⚠️ Recibirás un email de confirmación al nuevo correo")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Label("Email", systemImage: "envelope.fill")
                } footer: {
                    Text("El cambio de email requiere verificación. Por seguridad, está deshabilitado temporalmente.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Password Section
                Section {
                    Toggle(isOn: $showPasswordFields) {
                        Label("Cambiar contraseña", systemImage: "key.fill")
                    }

                    if showPasswordFields {
                        SecureField("Nueva contraseña", text: $newPassword)
                            .textContentType(.newPassword)

                        SecureField("Confirmar contraseña", text: $confirmPassword)
                            .textContentType(.newPassword)

                        if !newPassword.isEmpty {
                            passwordStrengthView
                        }
                    }
                } header: {
                    Label("Seguridad", systemImage: "lock.shield.fill")
                } footer: {
                    if showPasswordFields {
                        Text("La contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula y un número.")
                            .font(.caption)
                    }
                }

                // MARK: - Messages
                if let errorMessage = errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                if let successMessage = successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Editar Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await saveChanges() }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Guardando cambios...")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Password Strength View
    private var passwordStrengthView: some View {
        VStack(alignment: .leading, spacing: 4) {
            let strength = passwordStrength(newPassword)

            HStack {
                Text("Fortaleza:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(strength.text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(strength.color)

                Spacer()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.percentage, height: 4)
                }
            }
            .frame(height: 4)

            passwordRequirements
        }
        .padding(.vertical, 4)
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 2) {
            requirementRow(
                text: "Al menos 8 caracteres",
                isMet: newPassword.count >= 8
            )
            requirementRow(
                text: "Una letra mayúscula",
                isMet: newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
            )
            requirementRow(
                text: "Una letra minúscula",
                isMet: newPassword.range(of: "[a-z]", options: .regularExpression) != nil
            )
            requirementRow(
                text: "Un número",
                isMet: newPassword.range(of: "[0-9]", options: .regularExpression) != nil
            )
        }
        .font(.caption2)
    }

    private func requirementRow(text: String, isMet: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption2)
                .foregroundColor(isMet ? .green : .secondary)
            Text(text)
                .foregroundColor(isMet ? .green : .secondary)
        }
    }

    // MARK: - Validation
    private var isValid: Bool {
        // Nombre y apellidos no vacíos
        guard !nombre.trimmingCharacters(in: .whitespaces).isEmpty,
              !apellidos.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        // Si se cambia contraseña, validar
        if showPasswordFields && !newPassword.isEmpty {
            guard newPassword == confirmPassword,
                  isPasswordValid(newPassword) else {
                return false
            }
        }

        return true
    }

    private func isPasswordValid(_ password: String) -> Bool {
        let hasMinLength = password.count >= 8
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil

        return hasMinLength && hasUppercase && hasLowercase && hasNumber
    }

    private func passwordStrength(_ password: String) -> (text: String, color: Color, percentage: Double) {
        if password.isEmpty {
            return ("", .gray, 0)
        }

        var score = 0

        if password.count >= 8 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...2:
            return ("Débil", .red, 0.33)
        case 3...4:
            return ("Media", .orange, 0.66)
        default:
            return ("Fuerte", .green, 1.0)
        }
    }

    // MARK: - Actions
    private func saveChanges() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true

        defer { isLoading = false }

        do {
            // 1. Actualizar nombre y apellidos en perfiles
            if nombre != authViewModel.nombre || apellidos != authViewModel.apellidos {
                try await updateProfile()
            }

            // 2. Actualizar contraseña si se cambió
            if showPasswordFields && !newPassword.isEmpty {
                try await updatePassword()
            }

            // Success
            successMessage = "✅ Perfil actualizado correctamente"
            Logger.success("✅ Perfil actualizado correctamente")

            // Actualizar ViewModel
            authViewModel.nombre = nombre
            authViewModel.apellidos = apellidos

            // Cerrar después de 1.5 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }

        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            Logger.error("Error actualizando perfil: \(error.localizedDescription)")
        }
    }

    private func updateProfile() async throws {
        guard let userId = authViewModel.user?.id.uuidString else {
            throw NSError(domain: "EditProfile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        struct PerfilUpdate: Encodable {
            let nombre: String
            let apellidos: String
        }

        let update = PerfilUpdate(nombre: nombre, apellidos: apellidos)

        _ = try await supabase.from("perfiles")
            .update(update)
            .eq("id", value: userId)
            .execute()

        Logger.success("✅ Nombre y apellidos actualizados")
    }

    private func updatePassword() async throws {
        guard newPassword == confirmPassword else {
            throw NSError(domain: "EditProfile", code: 2, userInfo: [NSLocalizedDescriptionKey: "Las contraseñas no coinciden"])
        }

        guard isPasswordValid(newPassword) else {
            throw NSError(domain: "EditProfile", code: 3, userInfo: [NSLocalizedDescriptionKey: "La contraseña no cumple los requisitos"])
        }

        // Actualizar contraseña en Supabase Auth
        try await supabase.auth.update(user: UserAttributes(password: newPassword))

        Logger.success("✅ Contraseña actualizada")
    }
}

// MARK: - Preview
struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView(
            nombre: "Juan",
            apellidos: "García",
            email: "juan@example.com"
        )
        .environmentObject(AuthViewModel.shared)
    }
}
