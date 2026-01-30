import SwiftUI
import CoreLocation

/// Vista principal del perfil del usuario
struct ProfileView: View {

    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showEditProfile: Bool = false
    @State private var showVisitDetails: Bool = false
    @State private var showSettings: Bool = false

    // MARK: - Body
    var body: some View {
        ZStack {
            // Fondo que se extiende por completo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // Contenido
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    welcomeSection

                    // XP Progress Bar
                    progressBarView

                    // Personal Data Section
                    personalDataSection

                    // Statistics
                    ProfileStatsView(
                        camposVisitados: $profileVM.camposVisitados,
                        level: $profileVM.level,
                        totalAchievementsCount: $profileVM.totalAchievementsCount
                    )
                    .padding(.horizontal)

                    // Achievements Section
                    achievementsSection

                    // Visit History
                    VisitHistoryView(profileVM: profileVM, onShowDetails: {
                        showVisitDetails = true
                    })
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(L(.profileTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(.profileTitle))
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showVisitDetails) {
            VisitDetailView(
                allVisits: profileVM.allVisits,
                formatDate: profileVM.formatDate
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                profileVM: profileVM,
                userId: authViewModel.user?.id.uuidString ?? ""
            )
            .environmentObject(localizationManager)
            .environmentObject(ThemeManager.shared)
            .environmentObject(authViewModel)
            .environmentObject(geofenceManager)
            .environmentObject(locationManager)
            .environmentObject(camposViewModel)
            .preferredColorScheme(ThemeManager.shared.currentTheme.colorScheme)
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
        .onChange(of: themeManager.currentTheme) { _, _ in
            // Cerrar el modal de ajustes cuando cambia el tema
            if showSettings {
                showSettings = false
            }
        }
    }

    // MARK: - Welcome Section
    private var welcomeSection: some View {
        HStack(spacing: 16) {
            UserAvatarView(
                avatarURL: authViewModel.avatarURL,
                userName: authViewModel.nombre,
                size: 60
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(L(.profileHello, authViewModel.nombre))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("\(authViewModel.apellidos)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Progress Bar
    private var progressBarView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L(.profileLevel, profileVM.level))
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

    // MARK: - Achievements Section
    private var achievementsSection: some View {
        NavigationLink(destination: LogrosView().onAppear {
            profileVM.resetNewAchievementsCount()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(L(.logrosTitle))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        if profileVM.newAchievementsCount > 0 {
                            Text("\(profileVM.newAchievementsCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(10)
                        }

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                if let closestAchievement = profileVM.closestAchievement {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.2))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.yellow)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(closestAchievement.nombre)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                if let descripcion = closestAchievement.descripcion {
                                    Text(descripcion)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Text("+\(closestAchievement.xp ?? 0)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }

                        // Progress bar
                        let progress = profileVM.closestAchievementProgress
                        if progress.target > 0 {
                            VStack(spacing: 4) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                            .cornerRadius(4)

                                        Rectangle()
                                            .fill(Color.yellow)
                                            .frame(width: CGFloat(progress.current) / CGFloat(progress.target) * geometry.size.width, height: 8)
                                            .cornerRadius(4)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("\(progress.current) / \(progress.target)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int((Double(progress.current) / Double(progress.target)) * 100))%")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text(L(.logrosAllCompleted))
                            .font(.body)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Personal Data Section
    private var personalDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L(.profilePersonalInfo))
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showEditProfile = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text(L(.profileEdit))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }

            // Display Info
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "person.fill", label: L(.profileName), value: authViewModel.nombre)
                Divider()
                InfoRow(icon: "person.fill", label: L(.profileSurname), value: authViewModel.apellidos)
                Divider()
                InfoRow(icon: "envelope.fill", label: L(.profileEmail), value: authViewModel.user?.email ?? L(.profileNotAvailable))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(
                nombre: authViewModel.nombre,
                apellidos: authViewModel.apellidos,
                email: authViewModel.user?.email ?? ""
            )
            .environmentObject(authViewModel)
        }
    }

}

// MARK: - Info Row Helper
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
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
                    Text(L(.profileAutoCheckinInfoTitle))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(L(.profileAutoCheckinInfoDesc))
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L(.profileAutoCheckinInfoHow))
                            .font(.headline)
                            .padding(.top, 8)

                        Label(L(.profileAutoCheckinInfoDetect), systemImage: "location.circle")
                        Label(L(.profileAutoCheckinInfoWait), systemImage: "clock")
                        Label(L(.profileAutoCheckinInfoRegister), systemImage: "checkmark.circle.fill")
                        Label(L(.profileAutoCheckinInfoNoRepeat), systemImage: "shield.checkered")
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)

                    Text(L(.profileAutoCheckinInfoReqs))
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(L(.profileAutoCheckinInfoReqAlways), systemImage: "location.fill")
                        Label(L(.profileAutoCheckinInfoReqBackground), systemImage: "app.badge")
                        Label(L(.profileAutoCheckinInfoReqInternet), systemImage: "wifi")
                    }
                    .font(.subheadline)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(L(.profileAutoCheckinInfoTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L(.profileClose)) {
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
