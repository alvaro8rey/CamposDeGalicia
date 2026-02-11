import SwiftUI

/// Vista de usuario refactorizada - Usa componentes modulares
/// Esta es la versión refactorizada de UserView.swift
struct UserView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var camposViewModel: CamposViewModel

    // MARK: - Binding
    @Binding var distanciaPredeterminada: Double
    @Binding var shouldShowLogros: Bool

    // MARK: - Body
    var body: some View {
        Group {
            if authViewModel.isAuthenticated, let _ = authViewModel.user {
                // Authenticated View - Show Profile
                ProfileView(shouldShowLogros: $shouldShowLogros)
                    .environmentObject(authViewModel)
                    .environmentObject(geofenceManager)
                    .environmentObject(locationManager)
                    .environmentObject(camposViewModel)
            } else {
                // Not Authenticated - Show Login
                LoginView(onLoginSuccess: {
                    // Load initial data after login
                    Task {
                        try? await authViewModel.loadProfileData()
                    }
                })
                .environmentObject(authViewModel)
            }
        }
        .onAppear {
            authViewModel.checkCurrentSession()

            if authViewModel.isAuthenticated {
                Task {
                    try? await authViewModel.loadProfileData()
                }
            }
        }
    }
}

// MARK: - Preview
struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        UserView(
            distanciaPredeterminada: .constant(10.0),
            shouldShowLogros: .constant(false)
        )
            .environmentObject(GeofenceManager())
            .environmentObject(LocationManager())
            .environmentObject(CamposViewModel())
    }
}
