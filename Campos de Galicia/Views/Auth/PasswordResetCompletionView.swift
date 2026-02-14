import SwiftUI

/// Vista para establecer nueva contraseña tras usar el enlace de recuperación
struct PasswordResetCompletionView: View {

    // URL de recovery leída de UserDefaults (guardada en handleDeepLink)
    private var recoveryURL: URL? {
        UserDefaults.standard.string(forKey: "recovery_url").flatMap { URL(string: $0) }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var localization: LocalizationManager

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isSuccess: Bool = false
    @State private var sessionReady: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
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
                    VStack(spacing: 24) {
                        Spacer(minLength: 30)

                        // Icon
                        ZStack {
                            Circle()
                                .fill(isSuccess
                                    ? Color.green.opacity(0.15)
                                    : Color.blue.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: isSuccess ? "checkmark.lock.fill" : "lock.rotation")
                                .font(.system(size: 36))
                                .foregroundColor(isSuccess ? .green : .blue)
                        }

                        // Title & Description
                        Text(L(.passwordResetNewTitle))
                            .font(.title2).fontWeight(.bold)

                        if isSuccess {
                            Text(L(.passwordResetNewSuccess))
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else {
                            Text(L(.passwordResetNewDesc))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        if !isSuccess {
                            // Form
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(L(.editProfileNewPassword), systemImage: "lock.fill")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    SecureField("********", text: $newPassword)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .textContentType(.newPassword)
                                        .disabled(isLoading)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Label(L(.editProfileConfirmPassword), systemImage: "lock.fill")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(.secondary)

                                    SecureField("********", text: $confirmPassword)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .textContentType(.newPassword)
                                        .disabled(isLoading)
                                }

                                // Password hint
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption2)
                                    Text(L(.registerPasswordHint))
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Session status indicator
                                if !sessionReady {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text(L(.loading))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                // Error
                                if let error = errorMessage {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(10)
                                }

                                // Submit button
                                Button {
                                    Task { await changePassword() }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(isLoading ? "" : L(.passwordResetNewButton))
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: isFormValid ? [.blue, .green] : [.gray, .gray],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(!isFormValid || isLoading)
                            }
                            .padding(.horizontal, 24)
                        }

                        if isSuccess {
                            Button {
                                dismiss()
                            } label: {
                                Text(L(.ok))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle(L(.passwordResetNewTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSuccess {
                        Button(L(.cancel)) { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(isLoading)
            .task {
                await tryEstablishSession()
            }
        }
    }

    private var isFormValid: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    /// Establece la sesión de recovery en segundo plano mientras el usuario rellena el formulario.
    /// El token PKCE de la URL solo puede usarse una vez: lo consumimos aquí.
    private func tryEstablishSession() async {
        // Si ya hay sesión (caso raro: app en primer plano con sesión activa)
        if supabase.auth.currentUser != nil {
            print("✅ [Recovery] Sesión ya activa")
            sessionReady = true
            return
        }

        // Intercambiar el token de la URL por una sesión de recovery
        if let url = recoveryURL {
            do {
                _ = try await supabase.auth.session(from: url)
                print("✅ [Recovery] Sesión de recovery establecida")
                sessionReady = true
                return
            } catch {
                print("⚠️ [Recovery] session(from:) falló: \(error.localizedDescription)")
                // Mostrar error pero desbloquear formulario (changePassword dará el error final)
                errorMessage = localization.mapPasswordUpdateError(error)
                sessionReady = true
                return
            }
        }

        // Sin URL disponible: desbloquear igualmente (changePassword mostrará el error)
        print("⚠️ [Recovery] No hay URL de recovery disponible")
        sessionReady = true
    }

    /// Comprueba que la sesión sigue activa justo antes de cambiar la contraseña
    private func ensureSession() async -> Bool {
        return supabase.auth.currentUser != nil
    }

    private func changePassword() async {
        errorMessage = nil

        guard newPassword == confirmPassword else {
            errorMessage = L(.passwordResetNewMismatch)
            return
        }

        isLoading = true

        // Asegurar que hay sesión activa
        if supabase.auth.currentUser == nil {
            let sessionOk = await ensureSession()
            if !sessionOk {
                errorMessage = L(.passwordResetNewErrorSession)
                isLoading = false
                HapticFeedback.error()
                return
            }
        }

        do {
            try await AuthViewModel.shared.changePassword(newPassword: newPassword)

            // Limpiar estado de recovery
            try? await supabase.auth.signOut()
            AuthViewModel.shared.isRecoveryInProgress = false
            AuthViewModel.shared.isAuthenticated = false
            AuthViewModel.shared.user = nil

            withAnimation {
                isSuccess = true
            }
            HapticFeedback.success()
        } catch {
            errorMessage = localization.mapPasswordUpdateError(error)
            HapticFeedback.error()
        }

        isLoading = false
    }
}
