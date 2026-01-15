import SwiftUI

/// Vista de inicio de sesión
struct LoginView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
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
        ScrollView {
            VStack(spacing: 20) {
                // Logo/Icon
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                Text("Iniciar Sesión")
                    .font(.title)
                    .fontWeight(.bold)

                // Email field
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
                .padding(.horizontal)

                // Password field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Contraseña")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    SecureField("********", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoading)
                }
                .padding(.horizontal)

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Login button
                Button(action: { Task { await loginAction() } }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isLoading ? "Iniciando sesión..." : "Iniciar Sesión")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoginButtonDisabled ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoginButtonDisabled || isLoading)
                .padding(.horizontal)

                // Forgot password button
                Button(action: { showingResetPassword = true }) {
                    Text("¿Olvidaste tu contraseña?")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.top, 10)
                .disabled(isLoading)

                Divider()
                    .padding(.vertical, 20)

                // Register prompt
                VStack(spacing: 10) {
                    Text("¿No tienes cuenta?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: { showingRegister = true }) {
                        Text("Crear cuenta")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .disabled(isLoading)
                }
                .padding(.bottom, 40)
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
            errorMessage = "Error al iniciar sesión: \(error.localizedDescription)"
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
