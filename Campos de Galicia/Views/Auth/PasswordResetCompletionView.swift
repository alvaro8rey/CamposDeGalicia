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
        }
    }

    private var isFormValid: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    private func changePassword() async {
        errorMessage = nil

        guard newPassword == confirmPassword else {
            errorMessage = L(.passwordResetNewMismatch)
            return
        }

        isLoading = true

        do {
            try await AuthViewModel.shared.changePassword(newPassword: newPassword)
            // Actualizar estado de autenticación tras cambiar la contraseña
            AuthViewModel.shared.checkCurrentSession()
            withAnimation {
                isSuccess = true
            }
            HapticFeedback.success()
        } catch {
            errorMessage = L(.passwordResetNewError, error.localizedDescription)
            HapticFeedback.error()
        }

        isLoading = false
    }
}
