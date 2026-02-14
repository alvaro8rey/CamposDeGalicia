import SwiftUI

/// Vista para establecer nueva contraseña tras usar el enlace de recuperación
struct PasswordResetCompletionView: View {

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

    /// Espera a que la sesión de recovery esté lista (la establece handleDeepLink antes de abrir la vista)
    private func tryEstablishSession() async {
        // handleDeepLink ya llamó a session(from:) antes de mostrarnos.
        // Esperamos hasta 3s por si el SDK aún no ha propagado el usuario.
        if supabase.auth.currentUser != nil {
            print("✅ [Recovery] Sesión lista al abrir")
            sessionReady = true
            return
        }
        for attempt in 1...6 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s × 6 = máx 3s
            if supabase.auth.currentUser != nil {
                print("✅ [Recovery] Sesión detectada tras \(attempt × 500)ms")
                sessionReady = true
                return
            }
        }
        // Si tras 3s no hay sesión, desbloquear de todas formas.
        // changePassword() mostrará el error apropiado al intentar enviar.
        print("⚠️ [Recovery] Sin sesión tras 3s, desbloqueando formulario")
        sessionReady = true
    }

    /// Comprueba que hay sesión activa antes de cambiar la contraseña
    private func ensureSession() async -> Bool {
        if supabase.auth.currentUser != nil { return true }
        // Última espera corta (el SDK puede tardar un ciclo extra)
        try? await Task.sleep(nanoseconds: 500_000_000)
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
