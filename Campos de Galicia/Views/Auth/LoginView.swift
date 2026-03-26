import SwiftUI

/// Vista de inicio de sesión
struct LoginView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false

    // MARK: - Sheets
    @State private var showingResetPassword: Bool = false
    @State private var showingRegister: Bool = false

    // MARK: - Callbacks
    var onLoginSuccess: () -> Void = {}

    // MARK: - Body
    var body: some View {
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
                    // Logo/Icon with modern styling
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.blue, .green]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 120, height: 120)

                            Image(systemName: "map.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 60)

                        Text(L(.loginTitle))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(L(.loginSubtitle))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    // Form Card
                    VStack(spacing: Spacing.xl) {
                        // Email field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label(L(.loginEmail), systemImage: "envelope.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField(L(.loginEmailPlaceholder), text: $email)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(CornerRadius.md)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .disabled(isLoading)
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label(L(.loginPassword), systemImage: "lock.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            SecureField("********", text: $password)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(CornerRadius.md)
                                .disabled(isLoading)
                        }

                        // Error message
                        if let errorMessage = errorMessage {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(Opacity.light))
                            .cornerRadius(CornerRadius.sm + 2)
                        }

                        // Login button
                        Button(action: { Task { await loginAction() } }) {
                            HStack(spacing: Spacing.sm) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoading ? L(.loginLoading) : L(.loginButton))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.lg)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isLoginButtonDisabled ? [.gray, .gray] : [.blue, .green]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(CornerRadius.md)
                            .shadow(color: isLoginButtonDisabled ? .clear : .blue.opacity(Opacity.strong), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoginButtonDisabled || isLoading)

                        // Forgot password button
                        Button(action: { showingResetPassword = true }) {
                            Text(L(.loginForgotPassword))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.vertical, Spacing.xxxl)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(CornerRadius.xl)
                    .shadowLarge()
                    .padding(.horizontal, Spacing.xl)

                    // Register prompt
                    VStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text(L(.loginNoAccount))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button(action: { showingRegister = true }) {
                                Text(L(.loginCreateAccount))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingResetPassword) {
            PasswordResetRequestView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
                .environmentObject(authViewModel)
        }
        .onAppear {
            AnalyticsManager.shared.trackScreen("Login")
        }
    }

    // MARK: - Computed Properties
    private var isLoginButtonDisabled: Bool {
        email.isEmpty || password.isEmpty
    }

    // MARK: - Methods
    private func loginAction() async {
        errorMessage = nil
        isLoading = true

        do {
            try await authViewModel.login(email: email, password: password)
            try await authViewModel.loadProfileData()

            // Success
            onLoginSuccess()
            AnalyticsManager.shared.trackScreen("Main")

        } catch {
            errorMessage = localizationManager.mapLoginError(error)
            Logger.error("Login error: \(error.localizedDescription)")
            AnalyticsManager.shared.trackError(type: "login", message: error.localizedDescription)
        }

        isLoading = false
    }
}

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel.shared)
    }
}
