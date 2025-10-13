import SwiftUI
import Supabase
import UserNotifications

struct LogrosView: View {
    // Estado de usuario y progreso
    @State private var userId: String?
    @State private var camposVisitados = 0
    @State private var provinciasVisitadas = 0
    @State private var diasConsecutivos = 0

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

    // Errores / permisos
    @State private var errorMessage: String? = nil
    @State private var showPermissionAlert = false

    // 👉 Hora objetivo para la notificación diaria (15:00)
    private let DAILY_HOUR = 15
    private let DAILY_MIN  = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                dailyRewardSection
                achievementsSection
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .navigationTitle("Logros")
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Recompensa diaria")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            // Línea de días
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(1...6, id: \.self) { day in
                        VStack(spacing: 6) {
                            Text("Día \(day)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .frame(width: 56, height: 42)
                                Image(systemName: "circle.fill")
                                    .foregroundColor(day <= currentDay ? .orange : .gray)
                            }
                            Text("+\(dailyXPValue(for: day)) XP")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 64)
                    }
                }
            }

            if dailyXP > 0 && !hasClaimedToday {
                Button {
                    Task { await claimDailyReward() }
                } label: {
                    Text(isProcessingClaim ? "Procesando..." : "Reclamar")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isProcessingClaim || isButtonDisabled ? Color.gray : Color.pink)
                        .cornerRadius(12)
                }
                .disabled(isProcessingClaim || isButtonDisabled)
            } else if hasClaimedToday {
                Text("Recompensa ya reclamada hoy")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }

            // Botón opcional para test rápido (20s). Puedes eliminarlo cuando acabes.
            Button {
                scheduleOneOffTest(after: 20)
            } label: {
                Text("Probar notificación en 20s (temporal)")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Logros")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if isLoadingLogros {
                ProgressView("Cargando logros...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(groupedAchievements(), id: \.title) { group in
                    if !group.items.isEmpty {
                        Text(group.title)
                            .font(.headline)
                            .padding(.top, 6)

                        LazyVStack(spacing: 12) {
                            ForEach(group.items) { logro in
                                let isUnlocked = logrosDesbloqueados.contains(logro.id)
                                let (current, target) = progress(for: logro)

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                                            .foregroundColor(isUnlocked ? .green : .gray)
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

                                    if let d = logro.descripcion, !d.isEmpty {
                                        Text(d)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .lineSpacing(3)
                                    }

                                    if !isUnlocked && target > 0 {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("\(current)/\(target)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                Spacer()
                                            }
                                            ProgressView(value: Float(current), total: Float(target))
                                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                                .frame(height: 8)
                                                .cornerRadius(4)
                                        }
                                    } else if isUnlocked {
                                        Text("¡Desbloqueado!")
                                            .foregroundColor(.green)
                                            .font(.subheadline)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Agrupado y deduplicado

    private enum AchievementGroup: Int, CaseIterable {
        case camposVisitados = 0
        case rachas = 1
        case otros = 2

        var title: String {
            switch self {
            case .camposVisitados: return "Campos visitados"
            case .rachas:          return "Rachas"
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
            return .otros
        }
    }

    private struct GroupedSection {
        let title: String
        let items: [Logro]
    }

    private func groupedAchievements() -> [GroupedSection] {
        let deduped = deduplicateLogros(logros)

        func baseSort(_ a: Logro, _ b: Logro) -> Bool {
            let aUnlocked = logrosDesbloqueados.contains(a.id)
            let bUnlocked = logrosDesbloqueados.contains(b.id)
            if aUnlocked != bUnlocked { return !aUnlocked && bUnlocked }
            if let ao = a.orden, let bo = b.orden, ao != bo { return ao < bo }
            return a.nombre.localizedCaseInsensitiveCompare(b.nombre) == .orderedAscending
        }

        var buckets: [AchievementGroup: [Logro]] = [.camposVisitados: [], .rachas: [], .otros: []]
        for l in deduped { buckets[AchievementGroup.group(for: l), default: []].append(l) }
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
        scheduleDailyRewardNotification() // ⏰ Programa la diaria a las 15:00
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

            diasConsecutivos = try await computeConsecutiveDays(from: vArr)
        } catch {
            errorMessage = "Error al cargar progreso: \(error.localizedDescription)"
            camposVisitados = 0; provinciasVisitadas = 0; diasConsecutivos = 0
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
                let newAccess = AccesoDiario(
                    id: UUID(),
                    id_usuario: UUID(uuidString: userId)!,
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

            print("⚠️ No pude parsear fecha: \(s)")
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
        try? await LevelManager.shared.updateLevelAndXP(for: uid)
        await loadUserProgress()
        await loadLogrosDesbloqueados()
    }

    // MARK: - Notificaciones

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔧 Estado de notificaciones: \(settings.authorizationStatus.rawValue)")
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
        // Solo si hay recompensa pendiente
        guard !hasClaimedToday && !isButtonDisabled else {
            print("🔕 No se programa: ya reclamada o botón desactivado")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyRewardNotification"])
            return
        }

        // Limpia y programa nuevamente
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyRewardNotification"])

        var dateComponents = DateComponents()
        dateComponents.hour = DAILY_HOUR
        dateComponents.minute = DAILY_MIN

        let content = UNMutableNotificationContent()
        content.title = "¡Tu recompensa diaria está lista!"
        content.body  = "Pásate por la sección de Logros para reclamarla."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyRewardNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { err in
            if let err = err {
                print("❌ Error al programar diaria: \(err.localizedDescription)")
            } else {
                print("✅ Diaria programada a las \(DAILY_HOUR):\(String(format: "%02d", DAILY_MIN))")
                debugPendingNotifications()
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
            else {
                print("✅ Test programado en \(Int(seconds))s")
                debugPendingNotifications()
            }
        }
    }

    private func debugPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            print("📬 Pending notifications (\(reqs.count)):")
            for r in reqs { print(" • \(r.identifier)") }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
