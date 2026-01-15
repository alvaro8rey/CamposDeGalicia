import SwiftUI

/// Vista para solicitar reset de contraseña
struct PasswordResetRequestView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    // MARK: - State
    @State private var email: String = ""
    @State private var message: String? = nil
    @State private var isSuccess: Bool = false
    @State private var isLoading: Bool = false
    @State private var resendTimer: Int = 0

    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    Image(systemName: "lock.rotation")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.orange)
                        .padding(.top, 40)

                    Text("Restablecer Contraseña")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Email field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Correo Electrónico")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("tu@email.com", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(isLoading || resendTimer > 0)
                    }
                    .padding(.horizontal)

                    // Message
                    if let message = message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(isSuccess ? .green : .red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Send button
                    Button(action: { Task { await sendResetEmail() } }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            if resendTimer > 0 {
                                Text("Reenviar en \(resendTimer)s")
                            } else {
                                Text(isLoading ? "Enviando..." : "Enviar Enlace")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSendButtonDisabled ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSendButtonDisabled)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Recuperar Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackScreen("PasswordResetRequest")
            }
        }
    }

    // MARK: - Computed Properties
    private var isSendButtonDisabled: Bool {
        email.isEmpty || isLoading || resendTimer > 0
    }

    // MARK: - Methods
    private func sendResetEmail() async {
        guard !email.isEmpty else {
            message = "Introduce un correo electrónico válido."
            isSuccess = false
            return
        }

        isLoading = true
        message = nil

        do {
            try await authViewModel.requestPasswordReset(email: email)

            message = "Te hemos enviado un correo con el enlace para restablecer tu contraseña."
            isSuccess = true

            startResendCountdown()

            Logger.success("✅ Password reset email sent to: \(email)")

        } catch {
            message = "Error al enviar el correo: \(error.localizedDescription)"
            isSuccess = false

            Logger.error("Password reset error: \(error.localizedDescription)")
            AnalyticsManager.shared.trackError(type: "password_reset_request", message: error.localizedDescription)
        }

        isLoading = false
    }

    private func startResendCountdown() {
        resendTimer = 60

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Preview
struct PasswordResetRequestView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordResetRequestView()
            .environmentObject(AuthViewModel.shared)
    }
}
