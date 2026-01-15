import SwiftUI
import CoreLocation

/// Vista principal del perfil del usuario
struct ProfileView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var camposViewModel: CamposViewModel
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State
    @StateObject private var profileVM = ProfileViewModel()
    @State private var isEditing: Bool = false
    @State private var editedNombre: String = ""
    @State private var editedApellidos: String = ""
    @State private var showVisitDetails: Bool = false
    @State private var showInfoSheet: Bool = false
    @AppStorage("auto_checkin_enabled") private var autoCheckinStored: Bool = false

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Welcome Section
                welcomeSection

                // XP Progress Bar
                progressBarView

                // Auto Check-in Toggle
                autoCheckinSection

                // Statistics
                ProfileStatsView(
                    camposVisitados: $profileVM.camposVisitados,
                    level: $profileVM.level,
                    totalAchievementsCount: $profileVM.totalAchievementsCount
                )
                .padding(.horizontal)

                // Personal Data Section
                personalDataSection

                // Visit History
                VisitHistoryView(profileVM: profileVM, onShowDetails: {
                    showVisitDetails = true
                })
                .padding(.horizontal)

                // Preferences
                PreferencesView(
                    profileVM: profileVM,
                    userId: authViewModel.user?.id.uuidString ?? ""
                )
                .padding(.horizontal)

                // Action Buttons
                actionButtonsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Perfil")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: LogrosView().onAppear {
                    profileVM.resetNewAchievementsCount()
                }) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 20))
                }
                .badge(profileVM.newAchievementsCount > 0 ? profileVM.newAchievementsCount : 0)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: LevelsInfoView()) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .sheet(isPresented: $showVisitDetails) {
            VisitDetailView(
                allVisits: profileVM.allVisits,
                formatDate: profileVM.formatDate
            )
        }
        .sheet(isPresented: $showInfoSheet) {
            InfoSheetView()
        }
        .task {
            guard let userId = authViewModel.user?.id.uuidString else { return }
            await profileVM.loadAllData(for: userId, campos: camposViewModel.campos)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateXP)) { notification in
            if let userInfo = notification.userInfo,
               let level = userInfo["level"] as? Int,
               let xp = userInfo["current_xp"] as? Int,
               let xpNext = userInfo["xp_to_next_level"] as? Int {
                profileVM.level = level
                profileVM.currentXP = xp
                profileVM.xpToNextLevel = xpNext
                profileVM.updateFromNotification()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateVisits)) { _ in
            Task {
                guard let userId = authViewModel.user?.id.uuidString else { return }
                await profileVM.loadVisitHistory(for: userId, campos: camposViewModel.campos)
                await profileVM.loadAchievementsCount(for: userId)
                do {
                    try await LevelManager.shared.updateLevelAndXP(for: userId)
                } catch {
                    Logger.error("Error al actualizar nivel y XP: \(error.localizedDescription)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUnlockAchievement)) { _ in
            Task {
                guard let userId = authViewModel.user?.id.uuidString else { return }
                await profileVM.loadAchievementsCount(for: userId)
            }
        }
        .onAppear {
            AnalyticsManager.shared.trackScreen("Profile")
        }
    }

    // MARK: - Welcome Section
    private var welcomeSection: some View {
        VStack(spacing: 8) {
            Text("¡Hola, \(authViewModel.nombre)!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        }
    }

    // MARK: - Progress Bar
    private var progressBarView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Nivel \(profileVM.level)")
                    .font(.headline)
                Spacer()
                Text("\(profileVM.currentXP) / \(profileVM.xpToNextLevel) XP")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 20)
                        .cornerRadius(10)

                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: CGFloat(profileVM.currentXP) / CGFloat(profileVM.xpToNextLevel) * geometry.size.width, height: 20)
                        .cornerRadius(10)
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal)
    }

    // MARK: - Auto Check-in Section
    private var autoCheckinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $autoCheckinStored) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Auto Check-in")
                            .font(.headline)
                        Button(action: { showInfoSheet = true }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    Text("Registrar visitas automáticamente al estar 2 minutos cerca de un campo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: autoCheckinStored) { newValue in
                if newValue {
                    geofenceManager.startMonitoring(campos: camposViewModel.campos)
                    Logger.info("✅ Auto check-in activado")
                } else {
                    geofenceManager.stopMonitoring()
                    Logger.info("⏹ Auto check-in desactivado")
                }
            }

            if locationManager.authorizationStatus != .authorizedAlways && autoCheckinStored {
                Text("⚠️ Se necesitan permisos de ubicación 'Siempre' para el auto check-in")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Personal Data Section
    private var personalDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información Personal")
                .font(.title3)
                .fontWeight(.bold)

            if isEditing {
                // Edit Mode
                VStack(spacing: 12) {
                    TextField("Nombre", text: $editedNombre)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Apellidos", text: $editedApellidos)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    HStack {
                        Button("Cancelar") {
                            isEditing = false
                        }
                        .foregroundColor(.red)

                        Spacer()

                        Button("Guardar") {
                            Task { await saveChanges() }
                        }
                        .foregroundColor(.blue)
                    }
                }
            } else {
                // View Mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nombre:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(authViewModel.nombre)
                    }
                    Divider()
                    HStack {
                        Text("Apellidos:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(authViewModel.apellidos)
                    }

                    Button("Editar") {
                        editedNombre = authViewModel.nombre
                        editedApellidos = authViewModel.apellidos
                        isEditing = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.top, 8)
                }
            }

            if let errorMessage = profileVM.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await logout() } }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Cerrar Sesión")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Methods
    private func saveChanges() async {
        do {
            try await authViewModel.saveProfileChanges(nombre: editedNombre, apellidos: editedApellidos)
            isEditing = false
        } catch {
            profileVM.errorMessage = error.localizedDescription
        }
    }

    private func logout() async {
        do {
            try await authViewModel.logout()
            // Reset profile data
            profileVM.level = 1
            profileVM.currentXP = 0
            profileVM.xpToNextLevel = 100
            profileVM.camposVisitados = 0
            profileVM.historialCampos = []
            profileVM.totalAchievementsCount = 0
        } catch {
            profileVM.errorMessage = "Error al cerrar sesión: \(error.localizedDescription)"
        }
    }
}

// MARK: - Info Sheet
struct InfoSheetView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Auto Check-in")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("El auto check-in te permite registrar visitas a campos automáticamente cuando permaneces cerca de ellos durante al menos 2 minutos.")
                        .font(.body)

                    Text("Requisitos:")
                        .font(.headline)
                        .padding(.top)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Permisos de ubicación 'Siempre'", systemImage: "location.fill")
                        Label("Mantener la app en segundo plano", systemImage: "app.badge")
                        Label("Estar dentro de 100m del campo", systemImage: "circle.circle")
                    }
                    .font(.subheadline)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Información")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
                .environmentObject(AuthViewModel.shared)
                .environmentObject(GeofenceManager())
                .environmentObject(LocationManager())
                .environmentObject(CamposViewModel())
        }
    }
}
