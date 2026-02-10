import SwiftUI
import Supabase
import UserNotifications

struct LogrosView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var localizationManager: LocalizationManager

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

    // Detalle de logro
    @State private var selectedLogro: Logro? = nil
    @State private var selectedLogroUnlocked: Bool = false

    // Errores / permisos
    @State private var errorMessage: String? = nil
    @State private var showPermissionAlert = false

    // 👉 Hora objetivo para la notificación diaria (15:00)
    private let DAILY_HOUR = 15
    private let DAILY_MIN  = 0

    enum AchievementTab: String, CaseIterable {
        case pending
        case completed

        var localizedTitle: String {
            switch self {
            case .pending: return L(.logrosPending)
            case .completed: return L(.logrosCompleted)
            }
        }
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
            .padding(.bottom, 40)
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
        .navigationTitle(L(.logrosTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: LevelsInfoView()) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            Task { await boot() }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text(L(.notifDisabledTitle)),
                message: Text(L(.notifDisabledMessage)),
                primaryButton: .default(Text(L(.notifGoToSettings))) { openSettings() },
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
        .sheet(item: $selectedLogro) { logro in
            let (current, target) = progress(for: logro)
            LogroDetailView(
                logro: logro,
                isUnlocked: selectedLogroUnlocked,
                currentProgress: current,
                targetProgress: target
            )
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
            }
        )
    }

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(L(.logrosProgressTitle))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
            }

            HStack(spacing: 12) {
                StatCard(icon: "map.fill", value: "\(camposVisitados)", label: L(.logrosProgressCampos), color: .green)
                StatCard(icon: "mappin.and.ellipse", value: "\(provinciasVisitadas)", label: L(.logrosProgressProvincias), color: .orange)
                StatCard(icon: "star.bubble.fill", value: "\(reseñasEscritas)", label: L(.logrosProgressReviews), color: .purple)
            }

            // Streak card - full width, more prominent
            streakCard
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(diasConsecutivos)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(diasConsecutivos == 1 ? L(.logrosStreakDaysSingular) : L(.logrosStreakDaysPlural))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Text(L(.logrosStreakCurrent))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { day in
                        Circle()
                            .fill(
                                day < currentDay ? Color.green :
                                (day == currentDay ? Color.orange : Color.gray.opacity(0.3))
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                Text(L(.logrosStreakWeeklyCycle))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .overlay(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.08), Color.red.opacity(0.04), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(12)
                )
        )
        .cornerRadius(12)
    }

    private var achievementsTabSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tab picker
            Picker(L(.logrosTitle), selection: $selectedTab) {
                ForEach(AchievementTab.allCases, id: \.self) { tab in
                    Text(tab.localizedTitle).tag(tab)
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
                LoadingView(message: L(.logrosLoading), style: .skeleton)
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
                    title: L(.logrosAllCompleted),
                    message: L(.logrosAllCompletedMessage)
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
                                .onTapGesture {
                                    selectedLogro = logro
                                    selectedLogroUnlocked = false
                                }
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
                    title: L(.logrosNone),
                    message: L(.logrosNoneMessage)
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
                                .onTapGesture {
                                    selectedLogro = logro
                                    selectedLogroUnlocked = true
                                }
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
            case .camposVisitados: return L(.logrosCamposVisitados)
            case .rachas:          return L(.logrosRachasDiarias)
            case .reseñas:         return L(.logrosReseñas)
            case .otros:           return L(.logrosOtros)
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
        scheduleStreakWarningNotification()
        isLoadingLogros = false
    }

    private func loadUser() async {
        guard let currentUser = supabase.auth.currentUser else {
            errorMessage = L(.errorCouldNotAuthenticate)
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
            errorMessage = L(.errorUserNotAuthenticated)
            return
        }
        do {
            // Cargar visitas (últimas 500 para cálculos de logros)
            let vResp = try await supabase.from("visitas")
                .select("id_campo, created_at")
                .eq("id_usuario", value: userId)
                .order("created_at", ascending: false)
                .limit(500)
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
                    .in("id", values: Array(campoIds))
                    .execute()
                if let pArr = try JSONSerialization.jsonObject(with: pResp.data) as? [[String: Any]] {
                    let uniqProv = Set(pArr.compactMap { $0["provincia"] as? String })
                    provinciasVisitadas = uniqProv.count
                }
            }

            // Cargar reseñas (últimas 100 para conteo)
            let rResp = try await supabase.from("reseñas")
                .select("id")
                .eq("user_id", value: userId)
                .limit(100)
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

            guard let row = data.first else {
                guard let userUUID = UUID(uuidString: userId) else {
                    Logger.debug("⚠️ Error: userId inválido '\(userId)'")
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
                dailyXP = ProgressUtils.dailyXP(for: 1)
                hasClaimedToday = false
                isButtonDisabled = false
                return
            }

            currentDay = ProgressUtils.cycleDayFrom(consecutiveDays: row.dias_consecutivos)
            dailyXP = ProgressUtils.dailyXP(for: currentDay)

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

            // Si se reclama antes de las 15:00, cancelar la notificación de hoy
            // y re-programar para mañana. También cancelar aviso de racha.
            scheduleDailyRewardNotification()
            scheduleStreakWarningNotification()
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
        guard let firstDate = fechas.first else { return 0 }
        fechas.sort(by: >)

        let cal = Calendar.current
        var count = 1
        var currentDay = cal.startOfDay(for: firstDate)
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
        ProgressUtils.dailyXP(for: day)
    }

    private func refreshAfterVisit() async {
        guard let uid = userId else { return }
        do {
            try await LevelManager.shared.updateLevelAndXP(for: uid)
        } catch {
            Logger.debug("⚠️ Error al actualizar nivel y XP: \(error.localizedDescription)")
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
                        if let error = error { Logger.debug("Permisos notif error: \(error.localizedDescription)") }
                    }
            case .denied:
                DispatchQueue.main.async { self.showPermissionAlert = true }
            default:
                break
            }
        }
    }

    private func scheduleDailyRewardNotification() {
        // Programar la notificación SOLO si el usuario NO ha reclamado la recompensa hoy
        // Si ya la reclamó antes de las 15:00, no debe recibir notificación

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyRewardNotification"])

        let now = Date()
        let calendar = Calendar.current

        // Crear la hora objetivo de hoy a las 15:00
        var todayAt3PM = calendar.dateComponents([.year, .month, .day], from: now)
        todayAt3PM.hour = DAILY_HOUR
        todayAt3PM.minute = DAILY_MIN

        guard let targetTimeToday = calendar.date(from: todayAt3PM) else {
            Logger.debug("❌ Error al calcular la hora de notificación")
            return
        }

        // Determinar cuándo programar la notificación
        let shouldScheduleForToday = !hasClaimedToday && now < targetTimeToday
        let targetDate = shouldScheduleForToday ? targetTimeToday : calendar.date(byAdding: .day, value: 1, to: targetTimeToday)!

        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)

        let content = UNMutableNotificationContent()
        content.title = L(.appName)
        content.body  = L(.dailyRewardNotificationBody)
        content.sound = .default

        // Agregar datos para deep linking
        content.userInfo = [
            "type": "dailyReward"
        ]

        // NO usar repeats: true, programar solo para la próxima vez válida
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: "dailyRewardNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { err in
            if let err = err {
                Logger.debug("❌ Error al programar notificación diaria: \(err.localizedDescription)")
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                Logger.debug("✅ Notificación diaria programada para: \(dateFormatter.string(from: targetDate))")
            }
        }
    }

    private func scheduleStreakWarningNotification() {
        // Notificación de aviso de pérdida de racha:
        // Se programa para el día DESPUÉS de la notificación normal de recompensa.
        // Solo se programa si el usuario tiene una racha > 1 (algo que perder).

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyStreakWarning"])

        // Si ya reclamó hoy, no hay riesgo inmediato; programar para pasado mañana a las 10:00
        // Si no reclamó hoy, programar para mañana a las 10:00
        guard diasConsecutivos > 1 else { return }

        let now = Date()
        let calendar = Calendar.current

        // La notificación normal está a las 15:00 hoy/mañana.
        // El aviso de racha va 1 día después, a las 10:00 de la mañana.
        let daysToAdd = hasClaimedToday ? 2 : 1

        var warningComponents = calendar.dateComponents([.year, .month, .day], from: now)
        warningComponents.hour = 10
        warningComponents.minute = 0

        guard let baseDate = calendar.date(from: warningComponents),
              let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: baseDate) else {
            return
        }

        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)

        let content = UNMutableNotificationContent()
        content.title = L(.appName)
        content.body = L(.dailyStreakWarningBody, diasConsecutivos)
        content.sound = .default
        content.userInfo = ["type": "dailyReward"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: "dailyStreakWarning", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { err in
            if let err = err {
                Logger.debug("Error al programar aviso de racha: \(err.localizedDescription)")
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                Logger.debug("Aviso de racha programado para: \(dateFormatter.string(from: targetDate))")
            }
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

/// Vista de detalle para un logro (se abre al pulsar)
struct LogroDetailView: View {
    let logro: Logro
    let isUnlocked: Bool
    let currentProgress: Int
    let targetProgress: Int
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var progressPercentage: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Gran icono central
                    ZStack {
                        Circle()
                            .fill(
                                isUnlocked
                                    ? LinearGradient(colors: [.green.opacity(0.3), .green.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: isUnlocked ? "checkmark.seal.fill" : "trophy")
                            .font(.system(size: 44))
                            .foregroundColor(isUnlocked ? .green : .gray)
                    }
                    .padding(.top, 20)

                    // Nombre
                    Text(logro.nombre)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Descripción
                    if let descripcion = logro.descripcion, !descripcion.isEmpty {
                        Text(descripcion)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 30)
                    }

                    // XP
                    if let xp = logro.xp, xp > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                            Text("+\(xp) XP")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Estado
                    if isUnlocked {
                        // Completado
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            Text(L(.logrosDetailCompleted))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    } else if targetProgress > 0 {
                        // Progreso
                        VStack(spacing: 10) {
                            Text(L(.logrosDetailProgress))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(height: 10)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                                .padding(.horizontal, 20)

                            Text("\(currentProgress) / \(targetProgress)")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle(L(.logrosDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
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
