import SwiftUI
import PhotosUI

/// Vista de registro de nuevos usuarios
struct RegisterView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
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

                            Text(L(.registerTitle))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text(L(.registerSubtitle))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Form Card
                        VStack(spacing: 24) {
                            // Profile Photo Section
                            VStack(spacing: 12) {
                                Text(L(.registerProfilePhoto))
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
                                                Text(selectedPhotoData == nil ? L(.registerSelectPhoto) : L(.registerChangePhoto))
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
                                                    Text(L(.registerDeletePhoto))
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
                                    Label(L(.registerName), systemImage: "person.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField(L(.registerNamePlaceholder), text: $nombre)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .autocapitalization(.words)
                                        .disabled(isLoading)
                                }

                                // Apellidos
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(L(.registerSurname), systemImage: "person.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField(L(.registerSurnamePlaceholder), text: $apellidos)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .autocapitalization(.words)
                                        .disabled(isLoading)
                                }

                                // Email
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(L(.loginEmail), systemImage: "envelope.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    TextField(L(.loginEmailPlaceholder), text: $email)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .disabled(isLoading)
                                }

                                // Password
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(L(.loginPassword), systemImage: "lock.fill")
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
                                        Text(L(.registerPasswordHint))
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
                                    Text(isLoading ? L(.registerLoading) : L(.registerButton))
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
            .navigationTitle(L(.registerNavTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L(.cancel)) {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .alert(L(.registerSuccessTitle), isPresented: $showSuccessAlert) {
                Button(L(.ok)) {
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

        // Validar inputs usando InputValidator centralizado
        do {
            try InputValidator.validateName(nombre)
            try InputValidator.validateName(apellidos)
            try InputValidator.validateEmail(email)
            try InputValidator.validatePasswordStrength(password)

            // Validar tamaño de imagen si se seleccionó una
            if let photoData = selectedPhotoData {
                try InputValidator.validateImageSize(photoData, maxSizeInMB: 5.0)
            }
        } catch {
            // Mostrar error de validación en el formulario
            if let validationError = error as? ValidationError {
                errorMessage = validationError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
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
                    _ = try await authViewModel.uploadProfilePhoto(imageData: photoData)
                    Logger.success("✅ Foto de perfil subida correctamente")
                } catch {
                    // No fallar el registro si falla la foto, solo manejar el error
                    ErrorHandler.shared.handle(error, showToUser: false, context: "upload_profile_photo_on_register")
                }
            }

            successMessage = L(.registerSuccessMessage)
            showSuccessAlert = true

            Logger.success("✅ Registro exitoso: \(userId)")

        } catch {
            // Usar ErrorHandler para manejo consistente de errores
            let appError = convertToAppError(error)
            errorMessage = appError.errorDescription
            ErrorHandler.shared.handle(appError, showToUser: false, context: "register")
        }

        isLoading = false
    }

    /// Convierte errores de registro en AppError apropiados
    private func convertToAppError(_ error: Error) -> AppError {
        let errorDesc = error.localizedDescription.lowercased()

        if errorDesc.contains("user already registered") || errorDesc.contains("already registered") ||
           (errorDesc.contains("email") && errorDesc.contains("exists")) {
            return .emailAlreadyInUse
        }

        if errorDesc.contains("invalid email") || (errorDesc.contains("email") && errorDesc.contains("invalid")) {
            return .invalidInput("email")
        }

        if errorDesc.contains("password") && (errorDesc.contains("short") || errorDesc.contains("length")) {
            return .weakPassword
        }

        if errorDesc.contains("rate limit") || errorDesc.contains("too many requests") {
            return .networkTimeout
        }

        if errorDesc.contains("foreign key") || errorDesc.contains("perfiles_id_fkey") {
            return .databaseInsertFailed
        }

        if errorDesc.contains("duplicate key") || errorDesc.contains("conflict") {
            return .duplicateRecord
        }

        if errorDesc.contains("network") || errorDesc.contains("timeout") {
            return .networkError(error)
        }

        return .unknown(error)
    }
}

// MARK: - Preview
struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthViewModel.shared)
    }
}
