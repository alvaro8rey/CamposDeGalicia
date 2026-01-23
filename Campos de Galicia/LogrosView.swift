import SwiftUI
import Supabase
import UserNotifications

struct LogrosView: View {
    @Environment(\.colorScheme) var colorScheme

    // Estado de usuario y progreso
    @State private var userId: String?
    @State private var camposVisitados = 0
    @State private var provinciasVisitadas = 0
    @State private var diasConsecutivos = 0
    @State private var reseñasEscritas = 0

    // Recompensa diaria
    @State private var dailyXP = 0
    @State private var currentDay = 1
    @State private var hasClaimedToday = false
    @State private var isProcessingClaim = false
    @State private var isButtonDisabled = false

    // Logros
    @State private var logros: [Logro] = []
    @State private var logrosDesbloqueados: Set<UUID> = []
    @State private var isLoadingLogros = true

    // Tab selection
    @State private var selectedTab: AchievementTab = .pending

    // Errores / permisos
    @State private var errorMessage: String? = nil
    @State private var showPermissionAlert = false

    // 👉 Hora objetivo para la notificación diaria (15:00)
    private let DAILY_HOUR = 15
    private let DAILY_MIN  = 0

    enum AchievementTab: String, CaseIterable {
        case pending = "Pendientes"
        case completed = "Completados"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                dailyRewardSection

                // Estadísticas rápidas
                statsSection

                // Tabs de logros
                achievementsTabSection
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
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
        .navigationTitle("Logros y Recompensas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await boot() }
        }
        .onChange(of: hasClaimedToday) { _ in
            scheduleDailyRewardNotification() // reprograma/cancela según estado
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Notificaciones desactivadas"),
                message: Text("Para recibir recordatorios de la recompensa diaria, habilita las notificaciones en Ajustes."),
                primaryButton: .default(Text("Ir a Ajustes")) { openSettings() },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateXP)) { note in
            if let u = note.userInfo {
                camposVisitados     = u["camposVisitados"] as? Int ?? camposVisitados
                provinciasVisitadas = u["provinciasVisitadas"] as? Int ?? provinciasVisitadas
                diasConsecutivos    = u["diasConsecutivos"] as? Int ?? diasConsecutivos
                dailyXP             = u["dailyXP"] as? Int ?? dailyXP
                hasClaimedToday     = u["hasClaimedToday"] as? Bool ?? hasClaimedToday
                isButtonDisabled    = hasClaimedToday
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUnlockAchievement)) { _ in
            Task { await loadLogrosDesbloqueados() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateVisits)) { _ in
            Task { await refreshAfterVisit() }
        }
    }

    // MARK: - Secciones

    private var dailyRewardSection: some View {
        DailyRewardCardView(
            currentDay: currentDay,
            dailyXP: dailyXP,
            hasClaimedToday: hasClaimedToday,
            isProcessing: isProcessingClaim,
            onClaim: {
                Task { await claimDailyReward() }
            },
            onTestNotification: {
                scheduleOneOffTest(after: 20)
            }
        )
    }

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Tu Progreso")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
            }

            HStack(spacing: 12) {
                StatCard(icon: "map.fill", value: "\(camposVisitados)", label: "Campos", color: .green)
                StatCard(icon: "mappin.and.ellipse", value: "\(provinciasVisitadas)", label: "Provincias", color: .orange)
                StatCard(icon: "flame.fill", value: "\(diasConsecutivos)", label: "Racha", color: .red)
                StatCard(icon: "star.bubble.fill", value: "\(reseñasEscritas)", label: "Reseñas", color: .purple)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var achievementsTabSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tab picker
            Picker("Logros", selection: $selectedTab) {
                ForEach(AchievementTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 8)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if isLoadingLogros {
                LoadingView(message: "Cargando logros...", style: .skeleton)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                switch selectedTab {
                case .pending:
                    pendingAchievementsView
                case .completed:
                    completedAchievementsView
                }
            }
        }
    }

    private var pendingAchievementsView: some View {
        let grouped = groupedPendingAchievements()

        return VStack(alignment: .leading, spacing: 16) {
            if grouped.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "¡Felicidades!",
                    message: "Has completado todos los logros disponibles"
                )
            } else {
                ForEach(grouped, id: \.title) { group in
                    if !group.items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.title)
                                .font(.headline)
                                .foregroundColor(.primary)

                            ForEach(group.items) { logro in
                                let (current, target) = progress(for: logro)
                                CompactAchievementCard(
                                    achievement: logro,
                                    isUnlocked: false,
                                    currentProgress: current,
                                    targetProgress: target
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var completedAchievementsView: some View {
        let grouped = groupedCompletedAchievements()

        return VStack(alignment: .leading, spacing: 16) {
            if grouped.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: "Sin logros completados",
                    message: "Completa desafíos para desbloquear logros"
                )
            } else {
                ForEach(grouped, id: \.title) { group in
                    if !group.items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(group.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }

                            ForEach(group.items) { logro in
                                let (current, target) = progress(for: logro)
                                CompactAchievementCard(
                                    achievement: logro,
                                    isUnlocked: true,
                                    currentProgress: current,
                                    targetProgress: target
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Agrupado

    private enum AchievementGroup: Int, CaseIterable {
        case camposVisitados = 0
        case rachas = 1
        case reseñas = 2
        case otros = 3

        var title: String {
            switch self {
            case .camposVisitados: return "Campos visitados"
            case .rachas:          return "Rachas diarias"
            case .reseñas:         return "Reseñas"
            case .otros:           return "Otros"
            }
        }

        static func group(for logro: Logro) -> AchievementGroup {
            if let o = logro.orden {
                if (100...199).contains(o) { return .camposVisitados }
                if (300...399).contains(o) { return .rachas }
            }
            let cond = (logro.condicion ?? "").lowercased()
            if cond.contains("campos_visitados") { return .camposVisitados }
            if cond.contains("dias_visitados")   { return .rachas }
            if cond.contains("reseñas_escritas") { return .reseñas }
            return .otros
        }
    }

    private struct GroupedSection {
        let title: String
        let items: [Logro]
    }

    private func groupedPendingAchievements() -> [GroupedSection] {
        let deduped = deduplicateLogros(logros)
        let pending = deduped.filter { !logrosDesbloqueados.contains($0.id) }

        func baseSort(_ a: Logro, _ b: Logro) -> Bool {
            // Ordenar por progreso (más cerca primero)
            let (currentA, targetA) = progress(for: a)
            let (currentB, targetB) = progress(for: b)
            let progressA = targetA > 0 ? Double(currentA) / Double(targetA) : 0
            let progressB = targetB > 0 ? Double(currentB) / Double(targetB) : 0

            if abs(progressA - progressB) > 0.01 {
                return progressA > progressB
            }

            if let ao = a.orden, let bo = b.orden, ao != bo { return ao < bo }
            return a.nombre.localizedCaseInsensitiveCompare(b.nombre) == .orderedAscending
        }

        var buckets: [AchievementGroup: [Logro]] = [
            .camposVisitados: [],
            .rachas: [],
            .reseñas: [],
            .otros: []
        ]
        for l in pending { buckets[AchievementGroup.group(for: l), default: []].append(l) }
        for key in buckets.keys { buckets[key]?.sort(by: baseSort) }

        return AchievementGroup.allCases.map { group in
            GroupedSection(title: group.title, items: buckets[group] ?? [])
        }
    }

    private func groupedCompletedAchievements() -> [GroupedSection] {
        let deduped = deduplicateLogros(logros)
        let completed = deduped.filter { logrosDesbloqueados.contains($0.id) }

        func baseSort(_ a: Logro, _ b: Logro) -> Bool {
            if let ao = a.orden, let bo = b.orden, ao != bo { return ao < bo }
            return a.nombre.localizedCaseInsensitiveCompare(b.nombre) == .orderedAscending
        }

        var buckets: [AchievementGroup: [Logro]] = [
            .camposVisitados: [],
            .rachas: [],
            .reseñas: [],
            .otros: []
        ]
        for l in completed { buckets[AchievementGroup.group(for: l), default: []].append(l) }
        for key in buckets.keys { buckets[key]?.sort(by: baseSort) }

        return AchievementGroup.allCases.map { group in
            GroupedSection(title: group.title, items: buckets[group] ?? [])
        }
    }

    private func deduplicateLogros(_ arr: [Logro]) -> [Logro] {
        var seen: [String: Logro] = [:]
        for l in arr {
            let key = (l.condicion?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                ?? "nombre:\(l.nombre.lowercased())"
            if let existing = seen[key] {
                let xpA = existing.xp ?? 0
                let xpB = l.xp ?? 0
                if xpB > xpA {
                    seen[key] = l
                } else if xpB == xpA {
                    let ordA = existing.orden ?? Int.max
                    let ordB = l.orden ?? Int.max
                    if ordB < ordA { seen[key] = l }
                }
            } else {
                seen[key] = l
            }
        }
        return Array(seen.values)
    }

    // MARK: - Boot & Carga

    private func boot() async {
        await loadUser()
        requestNotificationPermission()
        await loadUserProgress()
        await loadLogros()
        await loadLogrosDesbloqueados()
        await updateDailyState()
        scheduleDailyRewardNotification()
        isLoadingLogros = false
    }

    private func loadUser() async {
        guard let currentUser = supabase.auth.currentUser else {
            errorMessage = "No se pudo autenticar el usuario"
            return
        }
        userId = currentUser.id.uuidString
        do {
            try await LevelManager.shared.updateLevelAndXP(for: currentUser.id.uuidString)
        } catch {
            errorMessage = "Error al actualizar logros y nivel: \(error.localizedDescription)"
        }
    }

    private func loadUserProgress() async {
        guard let userId = userId else {
            errorMessage = "Usuario no autenticado"
            return
        }
        do {
            // Cargar visitas
            let vResp = try await supabase.from("visitas")
                .select("id_campo, created_at")
                .eq("id_usuario", value: userId)
                .execute()
            let vData = vResp.data
            guard let vArr = try JSONSerialization.jsonObject(with: vData) as? [[String: Any]] else {
                camposVisitados = 0; provinciasVisitadas = 0; diasConsecutivos = 0
                return
            }
            let campoIds = Set(vArr.compactMap { $0["id_campo"] as? String })
            camposVisitados = campoIds.count

            // Cargar provincias
            if !campoIds.isEmpty {
                let pResp = try await supabase.from("campos")
                    .select("provincia")
                    .in("id", value: Array(campoIds))
                    .execute()
                if let pArr = try JSONSerialization.jsonObject(with: pResp.data) as? [[String: Any]] {
                    let uniqProv = Set(pArr.compactMap { $0["provincia"] as? String })
                    provinciasVisitadas = uniqProv.count
                }
            }

            // Cargar reseñas
            let rResp = try await supabase.from("reseñas")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
            if let rArr = try JSONSerialization.jsonObject(with: rResp.data) as? [[String: Any]] {
                reseñasEscritas = rArr.count
            }

            diasConsecutivos = try await computeConsecutiveDays(from: vArr)
        } catch {
            errorMessage = "Error al cargar progreso: \(error.localizedDescription)"
            camposVisitados = 0; provinciasVisitadas = 0; diasConsecutivos = 0; reseñasEscritas = 0
        }
    }

    private func loadLogros() async {
        do {
            let resp = try await supabase.from("logros")
                .select("id, nombre, descripcion, condicion, orden, xp")
                .execute()
            let dec = JSONDecoder()
            logros = try dec.decode([Logro].self, from: resp.data)
        } catch {
            errorMessage = "Error al cargar logros: \(error.localizedDescription)"
        }
    }

    private func loadLogrosDesbloqueados() async {
        guard let userId = userId else { return }
        do {
            let resp = try await supabase.from("logros_desbloqueados")
                .select("id_logro")
                .eq("id_usuario", value: userId)
                .execute()
            let dec = JSONDecoder()
            let arr = try dec.decode([[String: UUID]].self, from: resp.data)
            logrosDesbloqueados = Set(arr.compactMap { $0["id_logro"] })
        } catch {
            errorMessage = "Error al cargar logros desbloqueados: \(error.localizedDescription)"
        }
    }

    private func updateDailyState() async {
        guard let userId = userId else { return }
        do {
            let response = try await supabase.from("accesos_diarios")
                .select("id, id_usuario, ultimo_acceso, dias_consecutivos, ultima_recompensa_reclamada")
                .eq("id_usuario", value: userId)
                .execute()
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let data = try dec.decode([AccesoDiario].self, from: response.data)

            if data.isEmpty {
                guard let userUUID = UUID(uuidString: userId) else {
                    print("⚠️ Error: userId inválido '\(userId)'")
                    return
                }
                let newAccess = AccesoDiario(
                    id: UUID(),
                    id_usuario: userUUID,
                    ultimo_acceso: Date(),
                    dias_consecutivos: 1,
                    ultima_recompensa_reclamada: nil
                )
                let _ = try await supabase.from("accesos_diarios").insert(newAccess).execute()
                currentDay = 1
                dailyXP = dailyXPValue(for: currentDay)
                hasClaimedToday = false
                isButtonDisabled = false
                return
            }

            let row = data[0]
            currentDay = row.dias_consecutivos
            dailyXP = dailyXPValue(for: currentDay)

            let today = Calendar.current.startOfDay(for: Date())
            if let claimed = row.ultima_recompensa_reclamada {
                hasClaimedToday = Calendar.current.isDate(
                    today, equalTo: Calendar.current.startOfDay(for: claimed), toGranularity: .day
                )
            } else {
                hasClaimedToday = false
            }

            isButtonDisabled = hasClaimedToday
        } catch {
            currentDay = 1
            dailyXP = 20
            hasClaimedToday = false
            isButtonDisabled = false
        }
    }

    // MARK: - Acciones

    private func claimDailyReward() async {
        guard let userId = userId,
              !isProcessingClaim, dailyXP > 0, !hasClaimedToday, !isButtonDisabled else { return }

        isProcessingClaim = true
        isButtonDisabled = true
        do {
            try await LevelManager.shared.claimDailyReward(for: userId)
            hasClaimedToday = true
        } catch {
            errorMessage = "No se pudo reclamar la recompensa: \(error.localizedDescription)"
            isButtonDisabled = false
        }
        isProcessingClaim = false
    }

    // MARK: - Helpers (progreso y utilidades)

    private func progress(for logro: Logro) -> (current: Int, target: Int) {
        guard let c = logro.condicion else { return (0, 0) }
        if c.contains("campos_visitados") {
            let t = c.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(camposVisitados, t), t)
        }
        if c.contains("provincias_visitadas") {
            let t = c.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(provinciasVisitadas, t), t)
        }
        if c.contains("dias_visitados") {
            let t = c.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(diasConsecutivos, t), t)
        }
        if c.contains("reseñas_escritas") {
            let t = c.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(reseñasEscritas, t), t)
        }
        return (0, 0)
    }

    private func computeConsecutiveDays(from visitas: [[String: Any]]) async throws -> Int {
        let rawDates: [String] = visitas.compactMap { $0["created_at"] as? String }
        guard !rawDates.isEmpty else { return 0 }

        func parseDate(_ s: String) -> Date? {
            let dfTFrac = DateFormatter()
            dfTFrac.locale = Locale(identifier: "en_US_POSIX")
            dfTFrac.timeZone = TimeZone(secondsFromGMT: 0)
            dfTFrac.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            if let d = dfTFrac.date(from: s) { return d }

            let dfSpaceFrac = DateFormatter()
            dfSpaceFrac.locale = Locale(identifier: "en_US_POSIX")
            dfSpaceFrac.timeZone = TimeZone(secondsFromGMT: 0)
            dfSpaceFrac.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
            if let d = dfSpaceFrac.date(from: s) { return d }

            let dfT = DateFormatter()
            dfT.locale = Locale(identifier: "en_US_POSIX")
            dfT.timeZone = TimeZone(secondsFromGMT: 0)
            dfT.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let d = dfT.date(from: s) { return d }

            let dfSpace = DateFormatter()
            dfSpace.locale = Locale(identifier: "en_US_POSIX")
            dfSpace.timeZone = TimeZone(secondsFromGMT: 0)
            dfSpace.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let d = dfSpace.date(from: s) { return d }

            let isoNoTZ = ISO8601DateFormatter()
            isoNoTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoNoTZ.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = isoNoTZ.date(from: s) { return d }

            let isoTZ = ISO8601DateFormatter()
            isoTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            isoTZ.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = isoTZ.date(from: s) { return d }

            return nil
        }

        var fechas = rawDates.compactMap(parseDate)
        guard !fechas.isEmpty else { return 0 }
        fechas.sort(by: >)

        let cal = Calendar.current
        var count = 1
        var currentDay = cal.startOfDay(for: fechas[0])
        for i in 1..<fechas.count {
            let prevDay = cal.startOfDay(for: fechas[i])
            let diff = cal.dateComponents([.day], from: prevDay, to: currentDay).day ?? 0
            if diff == 1 { count += 1 }
            else if diff > 1 { break }
            currentDay = prevDay
        }
        return count
    }

    private func dailyXPValue(for day: Int) -> Int {
        switch day {
        case 1: return 20
        case 2: return 30
        case 3: return 40
        case 4: return 50
        case 5: return 70
        case 6: return 70
        default: return 20
        }
    }

    private func refreshAfterVisit() async {
        guard let uid = userId else { return }
        do {
            try await LevelManager.shared.updateLevelAndXP(for: uid)
        } catch {
            print("⚠️ Error al actualizar nivel y XP: \(error.localizedDescription)")
        }
        await loadUserProgress()
        await loadLogrosDesbloqueados()
    }

    // MARK: - Notificaciones

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if !granted { DispatchQueue.main.async { self.showPermissionAlert = true } }
                        if let error = error { print("Permisos notif error: \(error.localizedDescription)") }
                    }
            case .denied:
                DispatchQueue.main.async { self.showPermissionAlert = true }
            default:
                break
            }
        }
    }

    private func scheduleDailyRewardNotification() {
        guard !hasClaimedToday && !isButtonDisabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyRewardNotification"])
            return
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyRewardNotification"])

        var dateComponents = DateComponents()
        dateComponents.hour = DAILY_HOUR
        dateComponents.minute = DAILY_MIN

        let content = UNMutableNotificationContent()
        content.title = "Campos de Galicia"
        content.body  = "¡Tu recompensa diaria está lista! Pásate por la sección de Logros para reclamarla."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyRewardNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { err in
            if let err = err {
                print("❌ Error al programar diaria: \(err.localizedDescription)")
            }
        }
    }

    private func scheduleOneOffTest(after seconds: TimeInterval = 20) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["test_oneoff"])
        let content = UNMutableNotificationContent()
        content.title = "Test notificación"
        content.body  = "Debería aparecer en \(Int(seconds))s"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let req = UNNotificationRequest(identifier: "test_oneoff", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { err in
            if let err = err { print("❌ Error test: \(err.localizedDescription)") }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct CompactAchievementCard: View {
    let achievement: Logro
    let isUnlocked: Bool
    let currentProgress: Int
    let targetProgress: Int
    @Environment(\.colorScheme) var colorScheme

    var progressPercentage: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icono
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: isUnlocked ? "checkmark.seal.fill" : "trophy")
                    .font(.system(size: 20))
                    .foregroundColor(isUnlocked ? .green : .gray)
            }

            // Contenido
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.nombre)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                if !isUnlocked && targetProgress > 0 {
                    HStack(spacing: 4) {
                        ProgressView(value: progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(height: 6)

                        Text("\(currentProgress)/\(targetProgress)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                } else if let description = achievement.descripcion {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // XP
            Text("+\(achievement.xp ?? 0)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isUnlocked ? .green : .secondary)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .opacity(isUnlocked ? 1.0 : 0.85)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
