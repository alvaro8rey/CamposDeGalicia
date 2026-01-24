import SwiftUI
import PhotosUI

/// Vista de registro de nuevos usuarios
struct RegisterView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State
    @State private var nombre: String = ""
    @State private var apellidos: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.1),
                        Color.green.opacity(colorScheme == .dark ? 0.15 : 0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.blue, .green]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 100, height: 100)

                                Image(systemName: "person.crop.circle.fill.badge.plus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 20)

                            Text("Crear Cuenta")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Únete a la comunidad de Campos de Galicia")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Form Card
                        VStack(spacing: 24) {
                            // Profile Photo Section
                            VStack(spacing: 12) {
                                Text("Foto de perfil (opcional)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 16) {
                                    // Avatar Preview
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 80, height: 80)

                                        if let photoData = selectedPhotoData,
                                           let uiImage = UIImage(data: photoData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 35))
                                                .foregroundColor(.blue)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                            HStack {
                                                Image(systemName: "camera.fill")
                                                Text(selectedPhotoData == nil ? "Seleccionar foto" : "Cambiar foto")
                                            }
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                        }
                                        .onChange(of: selectedPhotoItem) { oldItem, newItem in
                                            Task {
                                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                                    selectedPhotoData = data
                                                }
                                            }
                                        }

                                        if selectedPhotoData != nil {
                                            Button(action: {
                                                selectedPhotoData = nil
                                                selectedPhotoItem = nil
                                            }) {
                                                HStack {
                                                    Image(systemName: "trash.fill")
                                                    Text("Eliminar")
                                                }
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }

                            // Form fields
                            VStack(spacing: 16) {
                                // Nombre
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Nombre", systemImage: "person.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField("Tu nombre", text: $nombre)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .autocapitalization(.words)
                                        .disabled(isLoading)
                                }

                                // Apellidos
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Apellidos", systemImage: "person.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField("Tus apellidos", text: $apellidos)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .autocapitalization(.words)
                                        .disabled(isLoading)
                                }

                                // Email
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Correo Electrónico", systemImage: "envelope.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField("tu@email.com", text: $email)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .disabled(isLoading)
                                }

                                // Password
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Contraseña", systemImage: "lock.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    SecureField("********", text: $password)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .disabled(isLoading)

                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("Mínimo 8 caracteres, con mayúscula, minúscula y número")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            // Error message
                            if let errorMessage = errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                            }

                            // Register button
                            Button(action: { Task { await registerAction() } }) {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    Text(isLoading ? "Creando cuenta..." : "Crear Cuenta")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: isRegisterButtonDisabled ? [.gray, .gray] : [.blue, .green]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: isRegisterButtonDisabled ? .clear : .green.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isRegisterButtonDisabled || isLoading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)

                        Spacer()
                    }
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
            // 1. Registrar usuario
            let userId = try await authViewModel.register(
                email: email,
                password: password,
                nombre: nombre,
                apellidos: apellidos
            )

            // 2. Subir foto de perfil si se seleccionó una
            if let photoData = selectedPhotoData {
                do {
                    // Usar el mismo método que EditProfileView
                    _ = try await authViewModel.uploadProfilePhoto(imageData: photoData)
                    Logger.success("✅ Foto de perfil subida correctamente")
                } catch {
                    // No fallar el registro si falla la foto, solo loggear
                    Logger.error("⚠️ Error al subir foto de perfil: \(error.localizedDescription)")
                }
            }

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
