import SwiftUI
import Supabase

struct LevelsInfoView: View {
    @State private var level: Int = 1
    @State private var currentXP: Int = 0
    @State private var xpToNextLevel: Int = 100
    @State private var errorMessage: String? = nil

    @State private var logros: [Logro] = []
    @State private var logrosDesbloqueados: [LogroDesbloqueado] = []
    @State private var dailyRewards: [AccesoDiario] = []

    @State private var isLoading: Bool = false
    @State private var lastUpdatedFromNotification: Date? = nil
    @Environment(\.colorScheme) var colorScheme

    private var validLogrosWithDetails: [(LogroDesbloqueado, Logro)] {
        logrosDesbloqueados
            .compactMap { ld in logros.first { $0.id == ld.id_logro }.map { (ld, $0) } }
            .sorted { $0.0.fecha_desbloqueo > $1.0.fecha_desbloqueo }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                titleSection
                progressSection
                explanationSection
                achievementsSection
                errorSection
                Spacer()
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Niveles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await loadInitialData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateXP)) { notification in
            if let userInfo = notification.userInfo,
               let newXP = userInfo["xp"] as? Int,
               let newLevel = userInfo["level"] as? Int,
               let newXPToNextLevel = userInfo["xpToNextLevel"] as? Int {
                level = newLevel
                currentXP = newXP
                xpToNextLevel = newXPToNextLevel
                lastUpdatedFromNotification = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUnlockAchievement)) { _ in
            Task {
                await loadLogrosDesbloqueados()
                await loadDailyRewards()
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
                .font(.title2)
            Text("Información sobre Niveles")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(gradient: Gradient(colors: [.blue, .purple]),
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                Text("\(level)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var progressSection: some View {
        // Cálculo “in-level”
        let base = LevelCurve.xpNeededToReachLevel(level)
        let span = max(LevelCurve.xpSpanForLevel(level), 1)
        let gainedInLevel = max(0, currentXP - base)
        let progress = min(max(Double(gainedInLevel) / Double(span), 0), 1)

        return VStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }


    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill").foregroundColor(.blue).font(.title3)
                Text("¿Para qué sirven los niveles?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Text("Los niveles representan tu progreso y dedicación en la app. A medida que subes de nivel, desbloqueas nuevas funcionalidades y obtienes mayor reconocimiento dentro de la comunidad.")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.blue.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var achievementsSection: some View {
        let hasLogros = !logrosDesbloqueados.isEmpty || !dailyRewards.isEmpty
        let hasValidLogros = !validLogrosWithDetails.isEmpty
        let hasInitialLogro = !logrosDesbloqueados.contains {
            $0.id_logro == UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        }

        return VStack(alignment: .leading, spacing: 15) {
            Text("Historial de Logros y Experiencia")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)

            if !hasLogros {
                Text("No has desbloqueado ningún logro ni recompensa diaria aún. ¡Explora más campos!")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.55))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
            } else {
                if hasValidLogros {
                    ForEach(validLogrosWithDetails, id: \.0.id) { desbloqueado, logro in
                        AchievementCard(logroDesbloqueado: desbloqueado, logro: logro)
                            .transition(.scale)
                    }
                }
                if !dailyRewards.isEmpty {
                    ForEach(dailyRewards) { reward in
                        DailyRewardCard(reward: reward)
                            .transition(.scale)
                    }
                }
                if hasInitialLogro {
                    InitialAchievementCard()
                        .transition(.scale)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var errorSection: some View {
        Group {
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Data

    private func loadInitialData() async {
        isLoading = true
        await loadUserData()
        await loadLogros()
        await loadLogrosDesbloqueados()
        await loadDailyRewards()
        isLoading = false
    }

    private func loadUserData() async {
        guard let currentUser = supabase.auth.currentUser else {
            errorMessage = "Usuario no autenticado"
            return
        }

        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            let response = try await supabase.from("niveles")
                .select("level, current_xp, xp_to_next_level")
                .eq("id_usuario", value: currentUser.id.uuidString)
                .single()
                .execute()

            if !response.data.isEmpty,
               let dict = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] {

                let newLevel = dict["level"] as? Int ?? 1
                let newCurrentXP = dict["current_xp"] as? Int ?? 0
                let newXPToNextLevel = dict["xp_to_next_level"] as? Int ?? 100

                if let lastUpdate = lastUpdatedFromNotification,
                   Date().timeIntervalSince(lastUpdate) < 2 {
                    // mantener valores actuales si justo acabamos de recibir notificación
                } else {
                    level = newLevel
                    currentXP = newCurrentXP
                    xpToNextLevel = newXPToNextLevel
                }
            } else {
                level = 1; currentXP = 0; xpToNextLevel = 100
            }
        } catch {
            errorMessage = "Error al cargar datos de nivel: \(error.localizedDescription)"
        }
    }

    private func loadLogros() async {
        do {
            let response = try await supabase.from("logros")
                .select("id, nombre, descripcion, condicion, orden, xp")
                .execute()
            let decoder = JSONDecoder()
            logros = try decoder.decode([Logro].self, from: response.data)
        } catch {
            errorMessage = "Error al cargar logros: \(error.localizedDescription)"
        }
    }

    private func loadLogrosDesbloqueados() async {
        guard let user = supabase.auth.currentUser else {
            errorMessage = "Usuario no autenticado"
            return
        }

        do {
            let response = try await supabase.from("logros_desbloqueados")
                .select()
                .eq("id_usuario", value: user.id.uuidString)
                .execute()

            let data = response.data
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard let array = jsonObject as? [[String: Any]] else {
                errorMessage = "Formato inesperado de logros desbloqueados"
                return
            }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            iso.timeZone = TimeZone(secondsFromGMT: 0)

            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            fallback.timeZone = TimeZone(secondsFromGMT: 0)

            logrosDesbloqueados = array.compactMap { dict in
                guard let idStr = dict["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let uidStr = dict["id_usuario"] as? String,
                      let uid = UUID(uuidString: uidStr),
                      let lidStr = dict["id_logro"] as? String,
                      let lid = UUID(uuidString: lidStr),
                      let fStr = dict["fecha_desbloqueo"] as? String,
                      let fecha = iso.date(from: fStr) ?? fallback.date(from: fStr)
                else { return nil }

                return LogroDesbloqueado(id: id, id_usuario: uid, id_logro: lid, fecha_desbloqueo: fecha)
            }
        } catch {
            errorMessage = "Error al cargar logros desbloqueados: \(error.localizedDescription)"
        }
    }

    private func loadDailyRewards() async {
        guard let user = supabase.auth.currentUser else {
            errorMessage = "Usuario no autenticado"
            return
        }

        do {
            let response = try await supabase.from("accesos_diarios")
                .select("id, id_usuario, ultimo_acceso, dias_consecutivos, ultima_recompensa_reclamada")
                .eq("id_usuario", value: user.id.uuidString)
                .execute()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let dataArray = try decoder.decode([AccesoDiario].self, from: response.data)
            dailyRewards = dataArray.filter { $0.ultima_recompensa_reclamada != nil }
        } catch {
            errorMessage = "Error al cargar recompensas diarias: \(error.localizedDescription)"
        }
    }
}


// MARK: - Cards (incluidas aquí para evitar errores de símbolo no encontrado)

struct AchievementCard: View {
    let logroDesbloqueado: LogroDesbloqueado
    let logro: Logro
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title3)

                Text(logro.nombre)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text("+\(logro.xp ?? 0) XP")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }

            if let descripcion = logro.descripcion, !descripcion.isEmpty {
                Text(descripcion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            Text("Desbloqueado el: \(DateFormatter.localizedString(from: logroDesbloqueado.fecha_desbloqueo, dateStyle: .medium, timeStyle: .none))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16) // 👈 margen lateral igual que el resto
    }
}


struct DailyRewardCard: View {
    let reward: AccesoDiario
    @Environment(\.colorScheme) var colorScheme

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func xp(for day: Int) -> Int {
        switch day {
        case 1: return 20
        case 2: return 30
        case 3: return 40
        case 4: return 50
        case 5, 6: return 70
        default: return 20
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Acceso Diario - Día \(reward.dias_consecutivos)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Spacer()

                Text("+\(xp(for: reward.dias_consecutivos)) XP")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }

            Text("Reclamado el: \(formatter.string(from: reward.ultima_recompensa_reclamada ?? Date()))")
                .font(.footnote)
                .foregroundColor(.secondary)

            Text("Recompensa por acceso diario.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16) // 👈 margen lateral igual que el resto
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InitialAchievementCard: View {
    @Environment(\.colorScheme) var colorScheme

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)

                Text("Creación de sesión")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Spacer()

                Text("+100 XP")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }

            Text("Desbloqueado el: \(formatter.string(from: Date()))")
                .font(.footnote)
                .foregroundColor(.secondary)

            Text("Recompensa por crear tu cuenta.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
