// LevelManager.swift
import Foundation
import Supabase

final class LevelManager {
    static let shared = LevelManager()
    private init() {}

    // Cambia a false si no quieres crear/forzar el logro inicial automáticamente
    private let INITIAL_ACHIEVEMENT_ENABLED = true
    private let INITIAL_ACHIEVEMENT_ID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let INITIAL_ACHIEVEMENT_XP = 100

    // MARK: - Public

    func updateLevelAndXP(for userId: String) async throws {
        guard let userIdUUID = UUID(uuidString: userId) else { throw LevelManagerError.invalidUserId }

        // 1) Visitas del usuario
        let visitasResponse = try await supabase.from("visitas")
            .select("id_campo, created_at")
            .eq("id_usuario", value: userId)
            .order("created_at", ascending: false)
            .execute()

        let visitasJSON = try JSONSerialization.jsonObject(with: visitasResponse.data, options: [])
        guard let visitasArray = visitasJSON as? [[String: Any]] else { throw LevelManagerError.dataParsingError }

        let uniqueCampoIds = Set(visitasArray.compactMap { $0["id_campo"] as? String })
        let camposVisitados = uniqueCampoIds.count

        // 2) Provincias visitadas
        var provinciasVisitadas = 0
        if !uniqueCampoIds.isEmpty {
            let provinciasResponse = try await supabase.from("campos")
                .select("provincia")
                .in("id", value: Array(uniqueCampoIds)) // ids como String (UUID-string)
                .execute()

            let provinciasJSON = try JSONSerialization.jsonObject(with: provinciasResponse.data, options: [])
            if let provinciasArray = provinciasJSON as? [[String: Any]] {
                provinciasVisitadas = Set(provinciasArray.compactMap { $0["provincia"] as? String }).count
            }
        }

        // 3) Días consecutivos (a partir de created_at ISO)
        // Racha de días desde created_at (soporta 'T' y espacio, con/sin fracciones)
        func parseVisitDate(_ s: String) -> Date? {
            // A) 'T' + microsegundos
            let dfTFrac = DateFormatter()
            dfTFrac.locale = Locale(identifier: "en_US_POSIX")
            dfTFrac.timeZone = TimeZone(secondsFromGMT: 0)
            dfTFrac.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            if let d = dfTFrac.date(from: s) { return d }

            // B) Espacio + microsegundos
            let dfSpaceFrac = DateFormatter()
            dfSpaceFrac.locale = Locale(identifier: "en_US_POSIX")
            dfSpaceFrac.timeZone = TimeZone(secondsFromGMT: 0)
            dfSpaceFrac.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
            if let d = dfSpaceFrac.date(from: s) { return d }

            // C) 'T' sin fracciones
            let dfT = DateFormatter()
            dfT.locale = Locale(identifier: "en_US_POSIX")
            dfT.timeZone = TimeZone(secondsFromGMT: 0)
            dfT.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let d = dfT.date(from: s) { return d }

            // D) Espacio sin fracciones
            let dfSpace = DateFormatter()
            dfSpace.locale = Locale(identifier: "en_US_POSIX")
            dfSpace.timeZone = TimeZone(secondsFromGMT: 0)
            dfSpace.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let d = dfSpace.date(from: s) { return d }

            // E) ISO8601 sin TZ (permite timestamps sin Z)
            let isoNoTZ = ISO8601DateFormatter()
            isoNoTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoNoTZ.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = isoNoTZ.date(from: s) { return d }

            // F) ISO8601 con TZ
            let isoTZ = ISO8601DateFormatter()
            isoTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            isoTZ.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = isoTZ.date(from: s) { return d }

            return nil
        }

        let fechasVisitas: [Date] = visitasArray
            .compactMap { $0["created_at"] as? String }
            .compactMap(parseVisitDate)
            .sorted(by: >)

        let diasConsecutivos: Int = {
            guard !fechasVisitas.isEmpty else { return 0 }
            let cal = Calendar.current
            var count = 1
            var currentDay = cal.startOfDay(for: fechasVisitas[0])
            for i in 1..<fechasVisitas.count {
                let prevDay = cal.startOfDay(for: fechasVisitas[i])
                let diff = cal.dateComponents([.day], from: prevDay, to: currentDay).day ?? 0
                if diff == 1 { count += 1 }
                else if diff > 1 { break }
                currentDay = prevDay
            }
            return count
        }()


        // 4) XP base
        let baseXP = camposVisitados * 10

        // 5) Logros y desbloqueados
        let logrosResponse = try await supabase.from("logros")
            .select("id, nombre, descripcion, condicion, orden, xp")
            .execute()
        let logros = try JSONDecoder().decode([Logro].self, from: logrosResponse.data)

        let logrosDesbloqueadosResponse = try await supabase.from("logros_desbloqueados")
            .select("id_logro")
            .eq("id_usuario", value: userId)
            .execute()
        let desbloqueadosRaw = try JSONDecoder().decode([[String: UUID]].self, from: logrosDesbloqueadosResponse.data)
        var logrosDesbloqueadosIds = Set(desbloqueadosRaw.compactMap { $0["id_logro"] })

        // 6) XP por logros ya desbloqueados
        var totalXP = baseXP
        for logro in logros where logrosDesbloqueadosIds.contains(logro.id) {
            totalXP += (logro.xp ?? 0)
        }

        // 7) XP inicial por crear sesión (si quieres contarlo siempre en totalXP)
        totalXP += INITIAL_ACHIEVEMENT_XP

        // 8) Acceso diario (no otorga automáticamente)
        let (dailyXP, hasClaimedToday) = try await checkDailyAccess(for: userIdUUID)

        // 9) Desbloquear nuevos logros
        var newLogros: [UUID] = []
        for logro in logros where !logrosDesbloqueadosIds.contains(logro.id) {
            let shouldUnlock = ProgressUtils.evaluate(
                condition: (logro.condicion ?? ""),
                campos: camposVisitados,
                provincias: provinciasVisitadas,
                dias: diasConsecutivos
            )
            if shouldUnlock {
                let nuevo = LogroDesbloqueado(
                    id: UUID(),
                    id_usuario: userIdUUID,
                    id_logro: logro.id,
                    fecha_desbloqueo: Date()
                )
                do {
                    try await supabase.from("logros_desbloqueados").insert(nuevo).execute()
                    totalXP += (logro.xp ?? 0)
                    newLogros.append(logro.id)
                    logrosDesbloqueadosIds.insert(logro.id)
                } catch {
                    print("⚠️ Error insertando logro \(logro.id): \(error)")
                }
            }
        }

        // 10) (Opcional) Forzar/crear logro inicial
        if INITIAL_ACHIEVEMENT_ENABLED && !logrosDesbloqueadosIds.contains(INITIAL_ACHIEVEMENT_ID) {
            let existsResp = try await supabase.from("logros")
                .select("id")
                .eq("id", value: INITIAL_ACHIEVEMENT_ID.uuidString)
                .execute()
            if let arr = try JSONSerialization.jsonObject(with: existsResp.data, options: []) as? [[String: Any]], arr.isEmpty {
                let initialLogro = Logro(
                    id: INITIAL_ACHIEVEMENT_ID,
                    nombre: "Creación de sesión",
                    descripcion: "Recompensa por crear tu cuenta.",
                    condicion: "campos_visitados>=0",
                    orden: 0,
                    xp: INITIAL_ACHIEVEMENT_XP
                )
                _ = try await supabase.from("logros").insert(initialLogro).execute()
            }
            let desbloqueo = LogroDesbloqueado(
                id: UUID(),
                id_usuario: userIdUUID,
                id_logro: INITIAL_ACHIEVEMENT_ID,
                fecha_desbloqueo: Date()
            )
            do {
                try await supabase.from("logros_desbloqueados").insert(desbloqueo).execute()
                totalXP += INITIAL_ACHIEVEMENT_XP
                newLogros.append(INITIAL_ACHIEVEMENT_ID)
                logrosDesbloqueadosIds.insert(INITIAL_ACHIEVEMENT_ID)
            } catch {
                print("⚠️ Error insertando logro inicial: \(error)")
            }
        }

        // 11) Nivel desde XP acumulado (curva extensible)
        let levelInfo = LevelCurve.levelAndNextThreshold(for: totalXP) // sin tope de 10
        let newLevel = levelInfo.level
        let xpToNextLevel = levelInfo.nextThresholdXP
        let currentXP = totalXP

        // 12) Upsert en niveles
        let nivelData = NivelData(
            id_usuario: userId,
            level: newLevel,
            current_xp: currentXP,
            xp_to_next_level: xpToNextLevel // umbral ACUMULADO del siguiente nivel
        )

        let existing = try await supabase.from("niveles")
            .select("id_usuario")
            .eq("id_usuario", value: userId)
            .execute()

        if let rows = try JSONSerialization.jsonObject(with: existing.data, options: []) as? [[String: Any]], !rows.isEmpty {
            if rows.count > 1 {
                _ = try await supabase.from("niveles").delete().eq("id_usuario", value: userId).execute()
                _ = try await supabase.from("niveles").insert(nivelData).execute()
            } else {
                _ = try await supabase.from("niveles").update(nivelData).eq("id_usuario", value: userId).execute()
            }
        } else {
            _ = try await supabase.from("niveles").insert(nivelData).execute()
        }

        // 13) Notifica (compatible con tu código actual)
        let payload: [String: Any] = [
            "xp": currentXP,
            "level": newLevel,
            "xpToNextLevel": xpToNextLevel,
            "camposVisitados": camposVisitados,
            "provinciasVisitadas": provinciasVisitadas,
            "diasConsecutivos": diasConsecutivos,
            "dailyXP": dailyXP,
            "hasClaimedToday": hasClaimedToday
        ]

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didUpdateXP, object: nil, userInfo: payload)
            // Si no tienes ProgressStore, deja solo la notificación.
            // ProgressStore.shared.applyNotificationPayload(payload)
        }

        // 14) Notifica nuevos logros (si los hay)
        if !newLogros.isEmpty {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .didUnlockAchievement, object: nil)
            }
        }
    }

    func claimDailyReward(for userId: String) async throws {
        guard let userIdUUID = UUID(uuidString: userId) else { throw LevelManagerError.invalidUserId }
        guard let currentUser = supabase.auth.currentUser, currentUser.id.uuidString == userId else {
            throw LevelManagerError.userIdMismatch
        }

        let df = ISO8601DateFormatter()
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let today = Calendar.current.startOfDay(for: Date())

        // Registro acceso diario
        let accResp = try await supabase.from("accesos_diarios")
            .select("id, id_usuario, ultimo_acceso, dias_consecutivos, ultima_recompensa_reclamada")
            .eq("id_usuario", value: userId)
            .execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let accessArray = try decoder.decode([AccesoDiario].self, from: accResp.data)
        guard let accessData = accessArray.first else { throw LevelManagerError.noAccessData }

        let dailyXP = ProgressUtils.dailyXP(for: accessData.dias_consecutivos)

        // Marca recompensa reclamada hoy
        let update = AccesoDiarioUpdate(
            ultimo_acceso: df.string(from: today),
            dias_consecutivos: accessData.dias_consecutivos,
            ultima_recompensa_reclamada: df.string(from: today)
        )
        _ = try await supabase.from("accesos_diarios")
            .update(update)
            .eq("id_usuario", value: userId)
            .execute()

        // Carga nivel actual y suma XP
        let nivelResp = try await supabase.from("niveles")
            .select("current_xp, level, xp_to_next_level")
            .eq("id_usuario", value: userId)
            .single()
            .execute()

        let nivelJSON = try JSONSerialization.jsonObject(with: nivelResp.data, options: [])
        guard let nivelDict = nivelJSON as? [String: Any],
              let currentXP = nivelDict["current_xp"] as? Int,
              let currentLevel = nivelDict["level"] as? Int else {
            throw LevelManagerError.dataParsingError
        }

        let newTotalXP = currentXP + dailyXP

        // Nuevo cálculo de nivel con curva extensible
        let levelInfo = LevelCurve.levelAndNextThreshold(for: newTotalXP)
        let newLevel = levelInfo.level
        let newXPToNext = levelInfo.nextThresholdXP

        let updatedNivel = NivelData(
            id_usuario: userId,
            level: newLevel,
            current_xp: newTotalXP,
            xp_to_next_level: newXPToNext
        )
        _ = try await supabase.from("niveles")
            .update(updatedNivel)
            .eq("id_usuario", value: userId)
            .execute()

        let payload: [String: Any] = [
            "xp": newTotalXP,
            "level": newLevel,
            "xpToNextLevel": newXPToNext,
            "dailyXP": dailyXP,
            "hasClaimedToday": true
        ]

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didUpdateXP, object: nil, userInfo: payload)
            // ProgressStore.shared.applyNotificationPayload(payload)
        }
    }

    // MARK: - Internals

    private func checkDailyAccess(for userId: UUID) async throws -> (Int, Bool) {
        let df = ISO8601DateFormatter()
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let today = Calendar.current.startOfDay(for: Date())

        let resp = try await supabase.from("accesos_diarios")
            .select("id, id_usuario, ultimo_acceso, dias_consecutivos, ultima_recompensa_reclamada")
            .eq("id_usuario", value: userId.uuidString)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var records = try decoder.decode([AccesoDiario].self, from: resp.data)

        // Limpia duplicados si los hay
        if records.count > 1 {
            records.sort { ($0.ultimo_acceso ?? .distantPast) > ($1.ultimo_acceso ?? .distantPast) }
            let idsToDelete = records.dropFirst().map { $0.id.uuidString }
            if !idsToDelete.isEmpty {
                _ = try await supabase.from("accesos_diarios").delete().in("id", value: idsToDelete).execute()
            }
            records = [records.first!]
        }

        let accessData: AccesoDiario
        if let first = records.first {
            accessData = first
        } else {
            let newAccess = AccesoDiario(
                id: UUID(),
                id_usuario: userId,
                ultimo_acceso: today,
                dias_consecutivos: 1,
                ultima_recompensa_reclamada: nil
            )
            _ = try await supabase.from("accesos_diarios").insert(newAccess).execute()
            return (ProgressUtils.dailyXP(for: 1), false)
        }

        let hasClaimedToday: Bool = {
            guard let last = accessData.ultima_recompensa_reclamada else { return false }
            let rewardDay = Calendar.current.startOfDay(for: last)
            return Calendar.current.isDate(today, equalTo: rewardDay, toGranularity: .day)
        }()

        // Actualiza racha si cambió de día
        if let lastAccess = accessData.ultimo_acceso {
            let cal = Calendar.current
            let lastDay = cal.startOfDay(for: lastAccess)
            let delta = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if delta >= 1 {
                let newStreak = (delta == 1) ? min(accessData.dias_consecutivos + 1, 6) : 1
                let update = AccesoDiarioUpdate(
                    ultimo_acceso: df.string(from: today),
                    dias_consecutivos: newStreak,
                    ultima_recompensa_reclamada: accessData.ultima_recompensa_reclamada.map { df.string(from: $0) }
                )
                _ = try await supabase.from("accesos_diarios")
                    .update(update)
                    .eq("id_usuario", value: userId.uuidString)
                    .execute()
                return (ProgressUtils.dailyXP(for: newStreak), hasClaimedToday)
            }
        }

        return (ProgressUtils.dailyXP(for: accessData.dias_consecutivos), hasClaimedToday)
    }
}

// MARK: - Errors
enum LevelManagerError: Error {
    case invalidUserId
    case dataParsingError
    case noAccessData
    case noAuthenticatedUser
    case userIdMismatch
}
