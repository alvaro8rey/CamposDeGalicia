import SwiftUI

/// Vista de registro de nuevos usuarios
struct RegisterView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    // MARK: - State
    @State private var nombre: String = ""
    @State private var apellidos: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""

    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.green)
                        .padding(.top, 20)

                    Text("Crear Cuenta")
                        .font(.title)
                        .fontWeight(.bold)

                    // Form fields
                    VStack(spacing: 15) {
                        // Nombre
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Nombre")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Tu nombre", text: $nombre)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .disabled(isLoading)
                        }

                        // Apellidos
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Apellidos")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Tus apellidos", text: $apellidos)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .disabled(isLoading)
                        }

                        // Email
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Correo Electrónico")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("tu@email.com", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .disabled(isLoading)
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Contraseña")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            SecureField("********", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isLoading)

                            Text("Mínimo 8 caracteres, con mayúscula, minúscula y número")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }

                    // Register button
                    Button(action: { Task { await registerAction() } }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isLoading ? "Creando cuenta..." : "Crear Cuenta")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRegisterButtonDisabled ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRegisterButtonDisabled || isLoading)
                    .padding(.horizontal)
                    .padding(.top, 10)

                    Spacer()
                }
            }
            .navigationTitle("Registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("¡Registro Exitoso!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .onAppear {
                AnalyticsManager.shared.trackScreen("Register")
            }
        }
    }

    // MARK: - Computed Properties
    private var isRegisterButtonDisabled: Bool {
        nombre.isEmpty || apellidos.isEmpty || email.isEmpty || password.isEmpty
    }

    // MARK: - Methods
    private func registerAction() async {
        errorMessage = nil

        // Validaciones
        guard !nombre.isEmpty, !apellidos.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Todos los campos son obligatorios."
            return
        }

        let passwordValidation = validatePassword(password)
        guard passwordValidation.isValid else {
            errorMessage = passwordValidation.message
            return
        }

        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Introduce un correo electrónico válido."
            return
        }

        isLoading = true

        do {
            let userId = try await authViewModel.register(
                email: email,
                password: password,
                nombre: nombre,
                apellidos: apellidos
            )

            successMessage = "Tu cuenta ha sido creada. Por favor revisa tu correo para verificar tu cuenta."
            showSuccessAlert = true

            Logger.success("✅ Registro exitoso: \(userId)")

        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = mapRegistrationError(errorDesc)

            Logger.error("Register error: \(errorDesc)")
            AnalyticsManager.shared.trackError(type: "register", message: errorDesc)
        }

        isLoading = false
    }

    private func validatePassword(_ password: String) -> (isValid: Bool, message: String?) {
        guard password.count >= 8 else {
            return (false, "La contraseña debe tener al menos 8 caracteres.")
        }

        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil

        guard hasUppercase else {
            return (false, "La contraseña debe contener al menos una letra mayúscula.")
        }
        guard hasLowercase else {
            return (false, "La contraseña debe contener al menos una letra minúscula.")
        }
        guard hasNumber else {
            return (false, "La contraseña debe contener al menos un número.")
        }

        return (true, nil)
    }

    private func mapRegistrationError(_ error: String) -> String {
        let msg = error.lowercased()

        if msg.contains("user already registered") || msg.contains("already registered") ||
           (msg.contains("email") && msg.contains("exists")) {
            return "Ese correo ya está registrado. Inicia sesión o usa '¿Olvidaste tu contraseña?'."
        }

        if msg.contains("invalid email") || (msg.contains("email") && msg.contains("invalid")) {
            return "El correo no es válido. Revisa el formato (ej. usuario@dominio.com)."
        }

        if msg.contains("password") && (msg.contains("short") || msg.contains("length")) {
            return "La contraseña es demasiado corta (mínimo 8 caracteres)."
        }

        if msg.contains("rate limit") || msg.contains("too many requests") {
            return "Has hecho demasiadas solicitudes. Inténtalo de nuevo en unos minutos."
        }

        if msg.contains("foreign key") || msg.contains("perfiles_id_fkey") {
            return "Se produjo un problema al crear tu perfil. Vuelve a intentarlo en unos segundos."
        }

        if msg.contains("duplicate key") || msg.contains("conflict") {
            return "Ya existía un perfil asociado a este usuario. Inicia sesión con tu correo."
        }

        return "No hemos podido crear tu cuenta ahora mismo. Inténtalo de nuevo en unos minutos."
    }
}

// MARK: - Preview
struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthViewModel.shared)
    }
}
