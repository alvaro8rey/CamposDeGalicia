import SwiftUI
import Supabase
import PhotosUI

/// Vista modal para editar el perfil completo del usuario
struct EditProfileView: View {

    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager

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

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isUploadingPhoto: Bool = false
    @State private var showDeletePhotoConfirmation: Bool = false
    @State private var showFullSizeImage: Bool = false

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
                // MARK: - Profile Photo Section
                Section {
                    VStack(spacing: 16) {
                        // Avatar Preview (tap to view full size)
                        Button(action: {
                            if authViewModel.avatarURL != nil || selectedPhotoData != nil {
                                showFullSizeImage = true
                            }
                        }) {
                            UserAvatarView(
                                avatarURL: selectedPhotoData != nil ? nil : authViewModel.avatarURL,
                                userName: nombre.isEmpty ? "U" : nombre,
                                size: 100
                            )
                            .overlay {
                                if let photoData = selectedPhotoData,
                                   let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(authViewModel.avatarURL == nil && selectedPhotoData == nil)

                        // Photo Picker Button
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(
                                authViewModel.avatarURL == nil && selectedPhotoData == nil ? L(.editProfileAddPhoto) : L(.editProfileChangePhoto),
                                systemImage: "camera.fill"
                            )
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderless)
                        .onChange(of: selectedPhotoItem) { oldItem, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                }
                            }
                        }

                        // Delete Photo Button
                        if authViewModel.avatarURL != nil || selectedPhotoData != nil {
                            Button(role: .destructive) {
                                if selectedPhotoData != nil {
                                    selectedPhotoData = nil
                                    selectedPhotoItem = nil
                                } else {
                                    showDeletePhotoConfirmation = true
                                }
                            } label: {
                                Label(L(.editProfileDeletePhoto), systemImage: "trash.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Label(L(.editProfilePhotoSection), systemImage: "person.crop.circle.fill")
                }

                // MARK: - Personal Info Section
                Section {
                    TextField(L(.editProfileNamePlaceholder), text: $nombre)
                        .textContentType(.givenName)
                        .autocapitalization(.words)

                    TextField(L(.editProfileSurnamePlaceholder), text: $apellidos)
                        .textContentType(.familyName)
                        .autocapitalization(.words)
                } header: {
                    Label(L(.editProfilePersonalInfo), systemImage: "person.fill")
                }

                // MARK: - Email Section
                Section {
                    HStack {
                        TextField(L(.editProfileEmailPlaceholder), text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(true) // Deshabilitado hasta implementar verificación

                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }

                    Button(action: {
                        errorMessage = L(.editProfileEmailChangeWarning)
                    }) {
                        HStack {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .foregroundColor(.blue)
                            Text(L(.editProfileRequestEmailChange))
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Label(L(.editProfileEmailSection), systemImage: "envelope.fill")
                } footer: {
                    Text(L(.editProfileEmailChangeFooter))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Password Section
                Section {
                    Toggle(isOn: $showPasswordFields) {
                        Label(L(.editProfileChangePassword), systemImage: "key.fill")
                    }

                    if showPasswordFields {
                        SecureField(L(.editProfileNewPassword), text: $newPassword)
                            .textContentType(.newPassword)

                        SecureField(L(.editProfileConfirmPassword), text: $confirmPassword)
                            .textContentType(.newPassword)

                        if !newPassword.isEmpty {
                            passwordStrengthView
                        }
                    }
                } header: {
                    Label(L(.editProfilePasswordSection), systemImage: "lock.shield.fill")
                } footer: {
                    if showPasswordFields {
                        Text(L(.editProfilePasswordFooter))
                            .font(.caption)
                    }
                }

                // MARK: - Messages
                if let errorMessage = errorMessage {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.title3)

                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let successMessage = successMessage {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)

                            Text(successMessage)
                                .foregroundColor(.green)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(L(.editProfileTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L(.cancel)) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L(.save)) {
                        Task { await saveChanges() }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .disabled(isLoading)
            .alert(L(.editProfileDeletePhoto) + "?", isPresented: $showDeletePhotoConfirmation) {
                Button(L(.cancel), role: .cancel) {}
                Button(L(.registerDeletePhoto), role: .destructive) {
                    Task {
                        await deletePhoto()
                    }
                }
            } message: {
                Text(L(.editProfileDeletePhotoConfirm))
            }
            .sheet(isPresented: $showFullSizeImage) {
                fullSizeImageView
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        LoadingView(
                            message: L(.editProfileSavingChanges),
                            style: .spinner
                        )
                        .foregroundColor(.white)
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
                Text(L(.editProfilePasswordStrength))
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
            var updatedItems: [String] = []

            // 1. Subir foto de perfil si hay una nueva
            if let photoData = selectedPhotoData {
                try await uploadPhoto(photoData)
                updatedItems.append("foto")
            }

            // 2. Actualizar nombre y apellidos en perfiles
            if nombre != authViewModel.nombre || apellidos != authViewModel.apellidos {
                try await updateProfile()
                updatedItems.append("datos personales")
            }

            // 3. Actualizar contraseña si se cambió
            if showPasswordFields && !newPassword.isEmpty {
                try await updatePassword()
                updatedItems.append("contraseña")
            }

            // Success - mostrar qué se actualizó
            if !updatedItems.isEmpty {
                let items = updatedItems.joined(separator: ", ")
                Logger.success("✅ Perfil actualizado: \(items)")

                // Actualizar ViewModel
                authViewModel.nombre = nombre
                authViewModel.apellidos = apellidos

                // Cerrar inmediatamente para que el toast se vea
                dismiss()

                // Toast de éxito (se mostrará después de cerrar)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    ToastManager.shared.success("✅ Perfil actualizado: \(items)")
                }
            } else {
                ToastManager.shared.warning("No se realizaron cambios")
            }

        } catch {
            // Los errores ya vienen personalizados de las funciones individuales
            ToastManager.shared.error(error.localizedDescription)
            Logger.error("❌ Error actualizando perfil: \(error.localizedDescription)")
        }
    }

    private func updateProfile() async throws {
        guard let userId = authViewModel.user?.id.uuidString else {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 2001,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo identificar tu usuario. Por favor, inicia sesión de nuevo"]
            )
        }

        // Validar que nombre y apellidos no estén vacíos
        let trimmedNombre = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApellidos = apellidos.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNombre.isEmpty else {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 2002,
                userInfo: [NSLocalizedDescriptionKey: "El nombre no puede estar vacío"]
            )
        }

        guard !trimmedApellidos.isEmpty else {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 2003,
                userInfo: [NSLocalizedDescriptionKey: "Los apellidos no pueden estar vacíos"]
            )
        }

        struct PerfilUpdate: Encodable {
            let nombre: String
            let apellidos: String
        }

        let update = PerfilUpdate(nombre: trimmedNombre, apellidos: trimmedApellidos)

        do {
            _ = try await supabase.from("perfiles")
                .update(update)
                .eq("id", value: userId)
                .execute()

            Logger.success("✅ Nombre y apellidos actualizados")
        } catch {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 2004,
                userInfo: [NSLocalizedDescriptionKey: "No se pudieron actualizar los datos. Verifica tu conexión e inténtalo de nuevo"]
            )
        }
    }

    private func updatePassword() async throws {
        guard newPassword == confirmPassword else {
            throw NSError(domain: "EditProfile", code: 2, userInfo: [NSLocalizedDescriptionKey: "Las contraseñas no coinciden"])
        }

        guard isPasswordValid(newPassword) else {
            throw NSError(domain: "EditProfile", code: 3, userInfo: [NSLocalizedDescriptionKey: "La contraseña no cumple los requisitos de seguridad"])
        }

        // Actualizar contraseña en Supabase Auth con manejo de errores personalizado
        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            Logger.success("✅ Contraseña actualizada")
        } catch {
            let message = localizationManager.mapPasswordUpdateError(error)
            throw NSError(domain: "CamposDeGalicia", code: 1001,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    /// Convierte errores de Supabase en mensajes personalizados amigables
    private func parsePasswordError(_ error: Error) -> NSError {
        let errorDescription = error.localizedDescription.lowercased()

        // Detectar tipos de error comunes
        if errorDescription.contains("same as the old password") ||
           errorDescription.contains("same password") ||
           errorDescription.contains("identical") {
            return NSError(
                domain: "CamposDeGalicia",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "La nueva contraseña debe ser diferente a la actual"]
            )
        }

        if errorDescription.contains("weak") ||
           errorDescription.contains("too short") ||
           errorDescription.contains("password is too weak") {
            return NSError(
                domain: "CamposDeGalicia",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "La contraseña es demasiado débil. Debe tener al menos 8 caracteres, una mayúscula, una minúscula y un número"]
            )
        }

        if errorDescription.contains("invalid") ||
           errorDescription.contains("malformed") {
            return NSError(
                domain: "CamposDeGalicia",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "El formato de la contraseña no es válido"]
            )
        }

        if errorDescription.contains("unauthorized") ||
           errorDescription.contains("not authenticated") ||
           errorDescription.contains("session") {
            return NSError(
                domain: "CamposDeGalicia",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Tu sesión ha expirado. Por favor, cierra sesión y vuelve a iniciarla"]
            )
        }

        if errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("timeout") {
            return NSError(
                domain: "CamposDeGalicia",
                code: 1005,
                userInfo: [NSLocalizedDescriptionKey: "Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo"]
            )
        }

        // Error genérico personalizado
        return NSError(
            domain: "CamposDeGalicia",
            code: 1099,
            userInfo: [NSLocalizedDescriptionKey: "No se pudo cambiar la contraseña. Por favor, inténtalo de nuevo más tarde"]
        )
    }

    private func uploadPhoto(_ data: Data) async throws {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        guard data.count > 0 else {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: "La imagen seleccionada no es válida"]
            )
        }

        // Verificar que es una imagen válida
        guard UIImage(data: data) != nil else {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 3002,
                userInfo: [NSLocalizedDescriptionKey: "El archivo seleccionado no es una imagen válida"]
            )
        }

        do {
            _ = try await authViewModel.uploadProfilePhoto(imageData: data)
            selectedPhotoData = nil
            selectedPhotoItem = nil
            Logger.success("✅ Foto de perfil subida")
        } catch {
            throw NSError(
                domain: "CamposDeGalicia",
                code: 3003,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo subir la foto. Verifica tu conexión e inténtalo de nuevo"]
            )
        }
    }

    private func deletePhoto() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authViewModel.deleteProfilePhoto()
            selectedPhotoData = nil
            selectedPhotoItem = nil
            ToastManager.shared.success("📸 Foto de perfil eliminada")
            Logger.success("✅ Foto de perfil eliminada")
        } catch {
            ToastManager.shared.error("No se pudo eliminar la foto. Inténtalo de nuevo")
            Logger.error("❌ Error al eliminar foto: \(error.localizedDescription)")
        }
    }

    // MARK: - Full Size Image View
    @ViewBuilder
    private var fullSizeImageView: some View {
        if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
            NavigationView {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L(.cancel)) {
                                showFullSizeImage = false
                            }
                        }
                    }
            }
        } else if let avatarURL = authViewModel.avatarURL, let url = URL(string: avatarURL) {
            NavigationView {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure, .empty:
                        ProgressView()
                    @unknown default:
                        ProgressView()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L(.close)) {
                            showFullSizeImage = false
                        }
                    }
                }
            }
        }
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
