
import SwiftUI
import Supabase
import CoreLocation
import UserNotifications
import UIKit
// MARK: - UserView

struct UserView: View {
    // MARK: Bindings
    @Binding var campos: [CampoModel]
    @Binding var distanciaPredeterminada: Double

    // MARK: Auth & Profile State
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isAuthenticated: Bool = false
    @State private var user: User? = nil
    @State private var nombre: String = ""
    @State private var apellidos: String = ""
    @State private var isEditing: Bool = false

    // MARK: UI Errors & Messages
    @State private var errorMessageProfile: String? = nil
    @State private var errorMessagePreferences: String? = nil
    @State private var errorMessageLevel: String? = nil

    // MARK: Password Change (in-app)
    @State private var showingChangePassword: Bool = false
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    // MARK: Visit History / Stats
    @State private var historialCampos: [CampoModel] = []
    @State private var camposVisitados: Int = 0
    @State private var isLoadingHistorial: Bool = false
    @State private var isHistoryExpanded: Bool = false
    @State private var newAchievementsCount: Int = 0
    @State private var totalAchievementsCount: Int = 0
    @State private var level: Int = 1
    @State private var currentXP: Int = 0
    @State private var xpToNextLevel: Int = 100
    @State private var lastUpdatedFromNotification: Date? = nil
    @State private var allVisits: [(campo: CampoModel, date: Date)] = []

    // MARK: Disclosure State
    @State private var isPersonalDataExpanded: Bool = true
    @State private var isPreferencesExpanded: Bool = false

    // MARK: Sheets & Modals
    @State private var showVisitDetails: Bool = false
    @State private var showingRegisterSheet = false
    @State private var showRegisterSuccessAlert = false
    @State private var registerSuccessMessage = ""

    // MARK: Forgot Password (request)
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    @State private var resetMessage: String? = nil
    @State private var resendTimer: Int = 0

    // MARK: Forgot Password (deep link -> set new)
    @State private var showingResetPasswordSheet: Bool = false
    @State private var newPasswordFromLink: String = ""
    @State private var confirmPasswordFromLink: String = ""
    @State private var resetPasswordError: String? = nil

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var geofenceManager: GeofenceManager
    @State private var showInfoSheet = false
    @EnvironmentObject var locationManager: LocationManager
    @AppStorage("auto_checkin_enabled") private var autoCheckinStored: Bool = false



    // MARK: Body
    var body: some View {
        Group {
            if isAuthenticated, let user = user {
                authenticatedView(user: user)
                    .navigationTitle("Perfil")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Perfil")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: LogrosView().onAppear { newAchievementsCount = 0 }) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 20))
                            }
                            .badge(newAchievementsCount > 0 ? newAchievementsCount : 0)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: LevelsInfoView()) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 18))
                            }
                        }
                    }
            } else {
                loginView()
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05),
                    colorScheme == .dark ? Color.green.opacity(0.1) : Color.green.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            Task {
                await loadUserData()
                await loadAchievementsCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateXP)) { notification in
            if let userInfo = notification.userInfo,
               let newXP = userInfo["xp"] as? Int,
               let newLevel = userInfo["level"] as? Int,
               let newXPToNextLevel = userInfo["xpToNextLevel"] as? Int {
                currentXP = newXP
                level = newLevel
                xpToNextLevel = newXPToNextLevel
                lastUpdatedFromNotification = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateVisits)) { _ in
            Task {
                await loadVisitHistory()
                await loadAchievementsCount()
                if let userId = user?.id.uuidString {
                    try? await LevelManager.shared.updateLevelAndXP(for: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUnlockAchievement)) { _ in
            Task { await loadAchievementsCount() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showResetPassword)) { _ in
            showingResetPassword = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingResetPasswordSheet = true
            }
        }
        .sheet(isPresented: $showVisitDetails) {
            VisitDetailView(allVisits: allVisits)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingChangePassword) {
            changePasswordSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingResetPasswordSheet) {
            resetPasswordFromLinkSheet()
                .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

}

// MARK: - Sheets

extension UserView {
    @ViewBuilder
    private func resetPasswordSheet() -> some View {
        VStack(spacing: 22) {
            Text("Restablecer Contraseña")
                .font(.title3).fontWeight(.semibold)
                .padding(.top, 20)

            Text("Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                Image(systemName: "envelope.fill").foregroundColor(.blue)
                TextField("Correo electrónico", text: $resetEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
            .padding(.horizontal, 20)

            if let resetMessage = resetMessage {
                Text(resetMessage)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            Button(action: {
                Task {
                    await sendPasswordResetEmail()
                    startResendCountdown()
                }
            }) {
                if resendTimer > 0 {
                    Text("Reenviar en \(resendTimer)s")
                        .font(.headline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                } else {
                    Text("Enviar enlace de recuperación")
                        .font(.headline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                        .padding(.horizontal, 20)
                }
            }
            .disabled(resendTimer > 0)
            .padding(.top, 10)

            Spacer()
        }
        .padding(.bottom, 30)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func registerSheet() -> some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Crear cuenta")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 10)

                Group {
                    TextField("Nombre", text: $nombre)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    TextField("Apellidos", text: $apellidos)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    SecureField("Contraseña", text: $password)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }

                if let errorMessage = errorMessageProfile {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: { Task { await registerAction() } }) {
                    Text("Crear cuenta")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                }
                .padding(.top, 10)

                Spacer(minLength: 10)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.top, 40)
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .alert(isPresented: $showRegisterSuccessAlert) {
            Alert(
                title: Text("Cuenta creada 🎉"),
                message: Text(registerSuccessMessage),
                primaryButton: .default(Text("Abrir Correo")) {
                    if let mailURL = URL(string: "message://"), UIApplication.shared.canOpenURL(mailURL) {
                        UIApplication.shared.open(mailURL)
                    }
                    showingRegisterSheet = false
                },
                secondaryButton: .cancel(Text("Cerrar")) {
                    showingRegisterSheet = false
                }
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.green.opacity(0.05)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func changePasswordSheet() -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "lock.fill").foregroundColor(.blue).font(.title2)
                Text("Cambiar Contraseña")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            SecureField("Nueva contraseña", text: $newPassword)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            SecureField("Confirmar contraseña", text: $confirmPassword)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            if newPassword != confirmPassword {
                Text("Las contraseñas no coinciden")
                    .font(.caption).foregroundColor(.red)
            }

            Button(action: {
                if newPassword == confirmPassword && !newPassword.isEmpty {
                    Task { await updatePassword() }
                }
            }) {
                Text("Guardar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            }

            Button("Cancelar") {
                showingChangePassword = false
                newPassword = ""
                confirmPassword = ""
            }
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func resetPasswordFromLinkSheet() -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "lock.rotation.open").foregroundColor(.blue).font(.title2)
                Text("Establecer nueva contraseña")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            SecureField("Nueva contraseña", text: $newPasswordFromLink)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))

            SecureField("Confirmar contraseña", text: $confirmPasswordFromLink)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))

            if let error = resetPasswordError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button(action: { Task { await finalizePasswordReset() } }) {
                Text("Guardar nueva contraseña")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            }

            Button("Cancelar") {
                showingResetPasswordSheet = false
                newPasswordFromLink = ""
                confirmPasswordFromLink = ""
                resetPasswordError = nil
            }
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Main Views

extension UserView {
    private func loginView() -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "person.fill").foregroundColor(.blue).font(.title2)
                Text("Iniciar Sesión")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            TextField("Email", text: $email)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            SecureField("Contraseña", text: $password)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            if let errorMessageProfile = errorMessageProfile {
                Text(errorMessageProfile)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: { Task { await loginAction() } }) {
                Text("Iniciar Sesión")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            }

            Button(action: { showingResetPassword = true }) {
                Text("¿Olvidaste tu contraseña?")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            .sheet(isPresented: $showingResetPassword) {
                resetPasswordSheet()
                    .presentationDetents([.medium])
            }

            HStack {
                Text("¿No tienes cuenta?").foregroundColor(.secondary)
                Button(action: { showingRegisterSheet = true }) {
                    Text("Crea una")
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showingRegisterSheet) {
                registerSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private func authenticatedView(user: User) -> some View {
        ScrollView {
            let welcomeSectionView = welcomeSection(user: user)
            let personalDataSectionView = personalDataSection()
            let preferencesSectionView = preferencesSection()
            let visitHistorySectionView = visitHistorySection()
            let statisticsSectionView = statisticsSection()
            let actionButtonsSectionView = actionButtonsSection()

            VStack(spacing: 30) {
                welcomeSectionView
                personalDataSectionView
                preferencesSectionView
                visitHistorySectionView
                statisticsSectionView
                actionButtonsSectionView
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16) // ÚNICO padding horizontal para todas las secciones
        }
        .onAppear { Task { await loadUserData() } }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateVisits)) { _ in
            Task { await loadVisitHistory() }
        }
        .navigationDestination(isPresented: .constant(false)) {
            LevelsInfoView()
        }
    }
}

// MARK: - Sections & Components

extension UserView {
    private func welcomeSection(user: User) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("\(nombre) \(apellidos)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Barra de XP
            progressBarView()

            // 🔄 Auto Check-in toggle + botón info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Toggle(isOn: Binding(
                        get: { autoCheckinStored },
                        set: { newValue in
                            autoCheckinStored = newValue
                            if newValue {
                                // Activa geovallas (solo geofences, sin GPS continuo)
                                geofenceManager.setAutoCheckin(true, campos: campos)
                            } else {
                                geofenceManager.setAutoCheckin(false, campos: campos)
                            }
                        }
                    )) {
                        Label("Auto Check-in", systemImage: "location.circle.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.top, 8)

                    // ℹ️ Botón de información
                    Button {
                        showInfoSheet.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }

                if autoCheckinStored {
                    Text("El auto check-in está activo.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Actívalo para registrar automáticamente visitas cercanas (2 min dentro del área).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)

            if let errorMessageLevel = errorMessageLevel {
                Text(errorMessageLevel)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(maxWidth: .infinity)
        // Hoja de información (tu hoja existente)
        .sheet(isPresented: $showInfoSheet) {
            AutoCheckinInfoSheet(locationManager: locationManager)
        }
        // Al entrar en la vista, sincroniza el estado persistido con el manager
        .onAppear {
            if autoCheckinStored {
                geofenceManager.setAutoCheckin(true, campos: campos)
            } else {
                geofenceManager.setAutoCheckin(false, campos: campos)
            }
        }
    }


    // MARK: - Barra de progreso XP final
    private func progressBarView() -> some View {
        // Cálculo “in-level”
        let base = LevelCurve.xpNeededToReachLevel(level)
        let span = max(LevelCurve.xpSpanForLevel(level), 1)
        let gainedInLevel = max(0, currentXP - base)
        let progress = min(max(Double(gainedInLevel) / Double(span), 0), 1)

        return VStack(spacing: 8) {
            // Barra visual
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .frame(height: 24)

                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorScheme == .dark ? Color.blue.opacity(0.6) : Color.green,
                                    colorScheme == .dark ? Color.green.opacity(0.6) : Color.blue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress), alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), lineWidth: 1)
                        )
                }
            }

            // Etiquetas debajo: nivel + XP
            VStack(spacing: 2) {
                HStack {
                    Text("Nivel \(level)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(gainedInLevel) / \(span) XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Spacer()
                    Text("Total: \(currentXP) XP")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 4)
        }
    }


    private func progressBarFill(geometry: GeometryProxy) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        colorScheme == .dark ? Color.blue.opacity(0.6) : Color.green,
                        colorScheme == .dark ? Color.green.opacity(0.6) : Color.blue
                    ]),
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(
                width: geometry.size.width * CGFloat(min(Float(currentXP), Float(xpToNextLevel)) / Float(xpToNextLevel)),
                alignment: .leading
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.5 : 0.7), lineWidth: 2)
                    .shadow(color: .white.opacity(colorScheme == .dark ? 0.3 : 0.5), radius: 2, x: 0, y: 0)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 3, x: 0, y: 2)
    }

    private func progressBarIndicator(geometry: GeometryProxy) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .shadow(radius: 2)
            .position(
                x: geometry.size.width * CGFloat(min(Float(currentXP), Float(xpToNextLevel)) / Float(xpToNextLevel)),
                y: 12
            )
    }

    private func personalDataSection() -> some View {
        DisclosureGroup(
            isExpanded: $isPersonalDataExpanded,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    if isEditing {
                        TextField("Nombre", text: $nombre)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                        TextField("Apellidos", text: $apellidos)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                        HStack(spacing: 12) {
                            Button(action: { Task { await saveProfileChanges() } }) {
                                Text("Guardar")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                            }
                            Button(action: { isEditing = false; errorMessageProfile = nil }) {
                                Text("Cancelar")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nombre: \(nombre.isEmpty ? "No especificado" : nombre)")
                                .font(.subheadline).foregroundColor(.primary)
                            Text("Apellidos: \(apellidos.isEmpty ? "No especificado" : apellidos)")
                                .font(.subheadline).foregroundColor(.primary)
                            Text("Correo: \(user?.email ?? "No disponible")")
                                .font(.subheadline).foregroundColor(.primary)
                        }
                        Button(action: { isEditing = true; errorMessageProfile = nil }) {
                            Text("Editar Información")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                        }
                    }

                    if let errorMessageProfile = errorMessageProfile {
                        Text(errorMessageProfile)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Text("Datos Personales")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 10, x: 0, y: 5)
    }

    private func preferencesSection() -> some View {
        DisclosureGroup(
            isExpanded: $isPreferencesExpanded,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Distancia predeterminada para Campos Cercanos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Distancia", selection: $distanciaPredeterminada) {
                        Text("10 km").tag(10.0)
                        Text("25 km").tag(25.0)
                        Text("50 km").tag(50.0)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)

                    Button(action: { Task { await savePreferences() } }) {
                        Text("Guardar Preferencias")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                    }

                    if let errorMessagePreferences = errorMessagePreferences {
                        Text(errorMessagePreferences)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Text("Preferencias de Mapa")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 10, x: 0, y: 5)
    }

    private func visitHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingHistorial {
                ProgressView("Cargando historial...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
                    .cornerRadius(15)
            } else if historialCampos.isEmpty {
                VStack(alignment: .leading) {
                    Text("Historial de Visitas")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("No has visitado ningún campo aún.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
                .cornerRadius(15)
            } else {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(historialCampos, id: \.id) { campo in
                                if campo.id != historialCampos.first?.id {
                                    Divider().padding(.leading, 62)
                                }
                                NavigationLink(destination: CampoDetalleView(campo: campo)) {
                                    historyCardView(campo: campo)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Button(action: { showVisitDetails = true }) {
                                Text("Ver más")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.top, 8)
                    },
                    label: {
                        Text("Historial de Visitas")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                )
                .padding()
                .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
                .cornerRadius(15)
            }
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 10, x: 0, y: 5)
    }

    private func historyCardView(campo: CampoModel) -> some View {
        NavigationLink(destination: CampoDetalleView(campo: campo)) {
            HStack(spacing: 12) {
                if let fotoURL = campo.foto_url, let url = URL(string: fotoURL), !fotoURL.isEmpty {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill().frame(width: 50, height: 50).cornerRadius(8).clipped()
                    } placeholder: {
                        Color.gray.opacity(0.3).frame(width: 50, height: 50).cornerRadius(8)
                    }
                } else {
                    AsyncImage(url: URL(string: "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png")) { image in
                        image.resizable().scaledToFill().frame(width: 50, height: 50).cornerRadius(8).clipped()
                    } placeholder: {
                        Color.gray.opacity(0.3).frame(width: 50, height: 50).cornerRadius(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(campo.nombre).font(.headline).foregroundColor(.primary)
                    Text("\(campo.localidad), \(campo.provincia)").font(.subheadline).foregroundColor(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding()
            .background(Color.clear)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, x: 0, y: 2)
        }
    }

    private func statisticCardView(title: String, value: String, iconName: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: iconName).font(.title2).foregroundColor(color)
            Text(value).font(.headline).fontWeight(.heavy).foregroundColor(.primary)
            Text(title).font(.caption).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground).opacity(colorScheme == .dark ? 0.7 : 0.9))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 6, x: 0, y: 3)
        )
    }

    private func statisticsSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Estadísticas de Usuario")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack {
                statisticCardView(title: "Visitas", value: "\(camposVisitados)", iconName: "figure.walk", color: .blue)
                statisticCardView(title: "Nivel actual", value: "\(level)", iconName: "star.circle.fill", color: .orange)
                statisticCardView(title: "Logros", value: "\(totalAchievementsCount)", iconName: "trophy.fill", color: .purple)
            }
            .padding(.top, 5)
        }
    }

    private func actionButtonsSection() -> some View {
        VStack(spacing: 12) {
            NavigationLink(destination: LogrosView()) {
                Text("Ver Logros")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            Button(action: { showingChangePassword = true }) {
                Text("Cambiar Contraseña")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            Button(action: { Task { await logoutAction() } }) {
                Text("Cerrar Sesión")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.red.opacity(0.1), .red.opacity(0.3)]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - Networking / Data Loading

extension UserView {
    private func loadUserData() async {
        if let currentUser = supabase.auth.currentUser {
            user = currentUser
            isAuthenticated = true
            Task {
                await loadProfileData()
                await loadVisitHistory()
                await loadPreferences()
                await loadLevelData()
            }
        }
    }

    private func loadLevelData() async {
        guard let currentUser = supabase.auth.currentUser else {
            print("ℹ️ (loadLevelData) Usuario no autenticado — se omite carga de nivel")
            return
        }
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            let response = try await supabase.from("niveles")
                .select("level, current_xp, xp_to_next_level")
                .eq("id_usuario", value: currentUser.id.uuidString)
                .limit(1)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: response.data, options: [])
            if let array = jsonObject as? [[String: Any]], !array.isEmpty {
                let dict = array[0]
                let newLevel = dict["level"] as? Int ?? 1
                let newCurrentXP = dict["current_xp"] as? Int ?? 0
                let newXPToNextLevel = dict["xp_to_next_level"] as? Int ?? 100

                if let lastUpdate = lastUpdatedFromNotification, Date().timeIntervalSince(lastUpdate) < 2 {
                    // Usa valores actuales si hay notificación reciente
                } else {
                    level = newLevel
                    currentXP = newCurrentXP
                    xpToNextLevel = newXPToNextLevel
                }
            } else {
                errorMessageLevel = "Error: No se encontraron datos de nivel"
                level = 1; currentXP = 0; xpToNextLevel = 100
            }
        } catch {
            errorMessageLevel = "Error al cargar datos de nivel: \(error.localizedDescription)"
            level = 1; currentXP = 0; xpToNextLevel = 100
        }
    }

    private func loadProfileData() async {
        do {
            let perfilResponse = try await supabase.from("perfiles")
                .select("nombre, apellidos")
                .eq("id", value: user!.id.uuidString)
                .single()
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: perfilResponse.data, options: [])
            if let dict = jsonObject as? [String: Any] {
                nombre = dict["nombre"] as? String ?? ""
                apellidos = dict["apellidos"] as? String ?? ""
            }
        } catch {
            errorMessageProfile = "Error al cargar el perfil: \(error.localizedDescription)"
        }
    }

    private func loadVisitHistory() async {
        isLoadingHistorial = true
        defer { isLoadingHistorial = false }

        do {
            let visitasResponse = try await supabase.from("visitas")
                .select("id_campo, created_at")
                .eq("id_usuario", value: user!.id.uuidString)
                .order("created_at", ascending: true)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: visitasResponse.data, options: [])
            if let array = jsonObject as? [[String: Any]] {
                let campoIds = array.compactMap { $0["id_campo"] as? String }
                let uniqueCampoIds = Set(campoIds.map { $0.lowercased() })
                camposVisitados = uniqueCampoIds.count

                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                df.locale = Locale(identifier: "en_US_POSIX")
                df.timeZone = TimeZone(secondsFromGMT: 0)

                allVisits = array.compactMap { dict -> (campo: CampoModel, date: Date)? in
                    guard let idCampo = dict["id_campo"] as? String,
                          let dateString = dict["created_at"] as? String,
                          let date = df.date(from: dateString) else { return nil }
                    guard let campo = campos.first(where: { $0.id.uuidString.lowercased() == idCampo.lowercased() }) else { return nil }
                    return (campo, date)
                }
                .sorted { $0.date > $1.date }

                let recent = allVisits.prefix(5)
                historialCampos = recent.map { $0.campo }
            }
        } catch {
            errorMessageProfile = "Error al cargar el historial: \(error.localizedDescription)"
        }
    }

    private func loadPreferences() async {
        guard let currentUser = supabase.auth.currentUser else {
            print("ℹ️ (loadPreferences) Usuario no autenticado — se omite carga de preferencias")
            return
        }
        do {
            let preferenciasResponse = try await supabase.from("preferencias")
                .select("id_usuario, distancia_predeterminada")
                .eq("id_usuario", value: currentUser.id.uuidString)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: preferenciasResponse.data, options: [])
            if let array = jsonObject as? [[String: Any]] {
                if array.isEmpty {
                    let preferences = Preferences(id_usuario: currentUser.id.uuidString, distancia_predeterminada: 10.0)
                    do {
                        _ = try await supabase.from("preferencias").insert(preferences).execute()
                        distanciaPredeterminada = 10.0
                    } catch {
                        if !error.localizedDescription.contains("duplicate key value") {
                            errorMessagePreferences = "Error al crear preferencias: \(error.localizedDescription)"
                        }
                        await fallbackLoadPreferences(currentUser.id.uuidString)
                    }
                } else if array.count == 1 {
                    let dict = array[0]
                    if let distancia = dict["distancia_predeterminada"] as? Double {
                        distanciaPredeterminada = distancia
                    }
                } else {
                    errorMessagePreferences = "Error: Múltiples registros de preferencias encontrados."
                    let dict = array[0]
                    if let distancia = dict["distancia_predeterminada"] as? Double {
                        distanciaPredeterminada = distancia
                    }
                }
            }
        } catch {
            errorMessagePreferences = "Error al cargar preferencias: \(error.localizedDescription)"
            await fallbackLoadPreferences(currentUser.id.uuidString)
        }
    }

    private func fallbackLoadPreferences(_ idUsuario: String) async {
        do {
            let response = try await supabase.from("preferencias")
                .select("distancia_predeterminada")
                .eq("id_usuario", value: idUsuario)
                .limit(1)
                .execute()

            if let array = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
               !array.isEmpty,
               let distancia = array[0]["distancia_predeterminada"] as? Double {
                distanciaPredeterminada = distancia
            }
        } catch {
            print("Error en fallback de carga de preferencias: \(error)")
        }
    }
}

// MARK: - Actions

extension UserView {
    private func loginAction() async {
        do {
            let response = try await supabase.auth.signIn(email: email, password: password)
            user = response.user
            isAuthenticated = true
            errorMessageProfile = nil
            errorMessagePreferences = nil
            errorMessageLevel = nil
            email = ""
            password = ""
            await loadProfileData()
            await loadVisitHistory()
            await loadPreferences()
            await loadLevelData()
        } catch {
            errorMessageProfile = "Error al iniciar sesión: \(error.localizedDescription)"
        }
    }

    private func registerAction() async {
        errorMessageProfile = nil

        guard !nombre.isEmpty, !apellidos.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessageProfile = "Todos los campos son obligatorios."
            return
        }
        guard password.count >= 6 else {
            errorMessageProfile = "La contraseña debe tener al menos 6 caracteres."
            return
        }
        guard email.contains("@"), email.contains(".") else {
            errorMessageProfile = "Introduce un correo electrónico válido."
            return
        }

        do {
            let authResp = try await supabase.auth.signUp(email: email, password: password)
            let userId = authResp.user.id.uuidString

            let perfil = Perfil(id: userId, nombre: nombre, apellidos: apellidos, isAdmin: false)
            do {
                try await supabase.from("perfiles").upsert(perfil).execute()
            } catch {
                errorMessageProfile = mapDBRegistrationError(error)
                return
            }

            registerSuccessMessage = "Te hemos enviado un correo a \(email) para verificar tu cuenta. Revisa tu bandeja de entrada."
            showRegisterSuccessAlert = true
        } catch {
            errorMessageProfile = mapAuthRegistrationError(error)
        }
    }

    private func updatePassword() async {
        guard supabase.auth.currentUser != nil else {
            errorMessageProfile = "Debes iniciar sesión para cambiar la contraseña."
            return
        }
        do {
            let attributes = UserAttributes(password: newPassword)
            try await supabase.auth.update(user: attributes)
            showingChangePassword = false
            newPassword = ""
            confirmPassword = ""
            errorMessageProfile = "Contraseña actualizada con éxito."
        } catch {
            errorMessageProfile = "Error al cambiar contraseña: \(error.localizedDescription)"
        }
    }

    private func finalizePasswordReset() async {
        guard !newPasswordFromLink.isEmpty, !confirmPasswordFromLink.isEmpty else {
            resetPasswordError = "Rellena ambos campos."
            return
        }
        guard newPasswordFromLink == confirmPasswordFromLink else {
            resetPasswordError = "Las contraseñas no coinciden."
            return
        }
        do {
            let attributes = UserAttributes(password: newPasswordFromLink)
            try await supabase.auth.update(user: attributes)
            DispatchQueue.main.async {
                showingResetPasswordSheet = false
                newPasswordFromLink = ""
                confirmPasswordFromLink = ""
                resetPasswordError = nil
                errorMessageProfile = "Contraseña actualizada con éxito."
            }
        } catch {
            resetPasswordError = "Error al actualizar contraseña: \(error.localizedDescription)"
        }
    }

    private func saveProfileChanges() async {
        do {
            guard !nombre.isEmpty, !apellidos.isEmpty else {
                errorMessageProfile = "Nombre y apellidos no pueden estar vacíos."
                return
            }
            let updatedPerfil: [String: String] = ["nombre": nombre, "apellidos": apellidos]
            _ = try await supabase.from("perfiles")
                .update(updatedPerfil)
                .eq("id", value: user!.id.uuidString)
                .execute()
            isEditing = false
            errorMessageProfile = "Información actualizada con éxito."
        } catch {
            errorMessageProfile = "Error al actualizar: \(error.localizedDescription)"
        }
    }

    private func savePreferences() async {
        do {
            let preferences = Preferences(id_usuario: user!.id.uuidString, distancia_predeterminada: distanciaPredeterminada)
            let response = try await supabase.from("preferencias").upsert(preferences).execute()
            print("Preferencias guardadas: \(response)")
            errorMessagePreferences = "Preferencias guardadas con éxito."
        } catch {
            errorMessagePreferences = "Error al guardar preferencias: \(error.localizedDescription)"
        }
    }

    private func logoutAction() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            user = nil
            nombre = ""
            apellidos = ""
            historialCampos = []
            camposVisitados = 0
            level = 1
            currentXP = 0
            xpToNextLevel = 100
            errorMessageProfile = nil
            errorMessagePreferences = nil
            errorMessageLevel = nil
        } catch {
            errorMessageProfile = "Error al cerrar sesión: \(error.localizedDescription)"
        }
    }

    private func sendPasswordResetEmail() async {
        guard !resetEmail.isEmpty else {
            resetMessage = "Introduce un correo electrónico válido."
            return
        }
        do {
            try await supabase.auth.resetPasswordForEmail(resetEmail)
            resetMessage = "Te hemos enviado un correo con el enlace para restablecer tu contraseña."
        } catch {
            resetMessage = "Error al enviar el correo: \(error.localizedDescription)"
        }
    }

    private func startResendCountdown() {
        resendTimer = 60
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendTimer > 0 { resendTimer -= 1 } else { timer.invalidate() }
        }
    }
}

// MARK: - Helpers

extension UserView {
    private func loadAchievementsCount() async {
        guard let user = supabase.auth.currentUser else {
            print("ℹ️ (loadAchievementsCount) Usuario no autenticado — se omite carga de logros")
            return
        }
        do {
            let response = try await supabase.from("logros_desbloqueados")
                .select("id")
                .eq("id_usuario", value: user.id.uuidString)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: response.data, options: [])
            guard let array = jsonObject as? [[String: Any]] else {
                errorMessageProfile = "Error: Formato de datos de logros desbloqueados inesperado"
                return
            }

            let newTotalAchievements = array.count
            if newTotalAchievements > totalAchievementsCount {
                newAchievementsCount = newTotalAchievements - totalAchievementsCount
            }
            totalAchievementsCount = newTotalAchievements
        } catch {
            errorMessageProfile = "Error al cargar conteo de logros: \(error.localizedDescription)"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func mapAuthRegistrationError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("user already registered") || msg.contains("already registered") || (msg.contains("email") && msg.contains("exists")) {
            return "Ese correo ya está registrado. Inicia sesión o usa “¿Olvidaste tu contraseña?”."
        }
        if msg.contains("invalid email") || (msg.contains("email") && msg.contains("invalid")) {
            return "El correo no es válido. Revisa el formato (ej. usuario@dominio.com)."
        }
        if msg.contains("password") && (msg.contains("short") || msg.contains("length")) {
            return "La contraseña es demasiado corta (mínimo 6 caracteres)."
        }
        if msg.contains("rate limit") || msg.contains("too many requests") {
            return "Has hecho demasiadas solicitudes. Inténtalo de nuevo en unos minutos."
        }
        return "No hemos podido crear tu cuenta ahora mismo. Inténtalo de nuevo en unos minutos."
    }

    private func mapDBRegistrationError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("foreign key") || msg.contains("perfiles_id_fkey") {
            return "Se produjo un problema al crear tu perfil. Vuelve a intentarlo en unos segundos."
        }
        if msg.contains("duplicate key") || msg.contains("already exists") || msg.contains("conflict") {
            return "Ya existía un perfil asociado a este usuario. Inicia sesión con tu correo."
        }
        return "No hemos podido guardar tu perfil. Inténtalo más tarde."
    }
}

// MARK: - VisitDetailView

struct VisitDetailView: View {
    let allVisits: [(campo: CampoModel, date: Date)]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Text("Historial de Visitas")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { withAnimation { dismiss() } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(allVisits, id: \.campo.id) { visit in
                            NavigationLink(destination: CampoDetalleView(campo: visit.campo)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        if let fotoURL = visit.campo.foto_url, let url = URL(string: fotoURL), !fotoURL.isEmpty {
                                            AsyncImage(url: url) { image in
                                                image.resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).clipped()
                                            } placeholder: {
                                                Color.gray.opacity(0.3).frame(width: 60, height: 60).cornerRadius(10)
                                            }
                                        } else {
                                            AsyncImage(url: URL(string: "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png")) { image in
                                                image.resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).clipped()
                                            } placeholder: {
                                                Color.gray.opacity(0.3).frame(width: 60, height: 60).cornerRadius(10)
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(visit.campo.nombre).font(.headline).foregroundColor(.primary)
                                            Text("\(visit.campo.localidad), \(visit.campo.provincia)").font(.subheadline).foregroundColor(.secondary)
                                            Text("Visitado el: \(formatDate(visit.date))").font(.caption).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
                                    .cornerRadius(15)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color.clear)
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Models & Utilities

struct Preferences: Codable {
    let id_usuario: String
    let distancia_predeterminada: Double
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct AutoCheckinInfoSheet: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    // Estado de permisos
    @State private var notifAuthorized: Bool = false
    @State private var notifProvisional: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // Qué es
                    infoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("¿Qué es el Auto Check-in?")
                                .font(.headline)
                            Text("Cuando estás cerca de un campo (≈500 m) y permaneces unos 2 minutos, registramos la visita automáticamente y te avisamos con una notificación.")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Cómo funciona
                    infoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("¿Cómo funciona?")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 6) {
                                bullet("Usa **geovallas** del sistema (muy bajo consumo).")
                                bullet("No rastreamos tu ubicación constantemente.")
                                bullet("Solo se comprueba si sigues dentro del área durante ~2 minutos.")
                                bullet("Si ya habías visitado ese campo, **no se repite**.")
                            }
                        }
                    }

                    // Permisos requeridos
                    infoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Permisos necesarios")
                                .font(.headline)

                            permRow(
                                title: "Ubicación (Cuando se use la app / Siempre)",
                                ok: isLocationAtLeastWhenInUse
                            )
                            permRow(
                                title: notifProvisional ? "Notificaciones (Provisional)" : "Notificaciones",
                                ok: notifAuthorized || notifProvisional
                            )

                            Text("Para que funcione con la app cerrada, activa “Siempre” en Ajustes.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Botón Ajustes
                    infoCard {
                        VStack(spacing: 10) {
                            Button {
                                openAppSettings()
                            } label: {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Abrir Ajustes de la app")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Estado actual
                    infoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estado actual")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• Ubicación: \(readableLocationStatus)")
                                Text("• Notificaciones: \(readableNotifStatus)")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.15), Color(UIColor.systemBackground).opacity(0.95)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
            )
            .navigationTitle("Auto Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshNotifStatus()
            }
        }
    }

    // MARK: - Subvistas reutilizables

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").bold()
            Text(LocalizedStringKey(text))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permRow(title: String, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(ok ? .green : .red)
            Text(title)
            Spacer()
            Text(ok ? "Otorgado" : "Pendiente")
                .font(.caption)
                .foregroundColor(ok ? .green : .secondary)
        }
    }

    // MARK: - Estado

    private var isLocationAtLeastWhenInUse: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    private var readableLocationStatus: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "No determinado"
        case .restricted:    return "Restringido"
        case .denied:        return "Denegado"
        case .authorizedWhenInUse: return "Cuando se use la app"
        case .authorizedAlways:    return "Siempre"
        @unknown default:    return "Desconocido"
        }
    }

    private var readableNotifStatus: String {
        if notifAuthorized { return "Permitidas" }
        if notifProvisional { return "Provisionales" }
        return "Denegadas"
    }

    // MARK: - Acciones

    private func refreshNotifStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notifAuthorized = (settings.authorizationStatus == .authorized)
                self.notifProvisional = (settings.authorizationStatus == .provisional)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
