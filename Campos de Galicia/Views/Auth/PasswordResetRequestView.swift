import SwiftUI

/// Vista para solicitar reset de contraseña
struct PasswordResetRequestView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
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

                    Text(L(.passwordResetTitle))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(L(.passwordResetDesc))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Email field
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L(.loginEmail))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField(L(.passwordResetEmailPlaceholder), text: $email)
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
                                Text(L(.passwordResetResendIn, resendTimer))
                            } else {
                                Text(isLoading ? L(.passwordResetSending) : L(.passwordResetButton))
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
            .navigationTitle(L(.passwordResetTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L(.cancel)) {
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
            message = L(.passwordResetInvalidEmail)
            isSuccess = false
            return
        }

        isLoading = true
        message = nil

        do {
            try await authViewModel.requestPasswordReset(email: email)

            message = L(.passwordResetSuccess)
            isSuccess = true

            startResendCountdown()

            Logger.success("✅ Password reset email sent to: \(email)")

        } catch {
            message = localizationManager.mapPasswordResetEmailError(error)
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
