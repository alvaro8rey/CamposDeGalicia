import Foundation
import Combine
import Supabase

final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published var level: Int = 1
    @Published var currentXP: Int = 0
    @Published var xpToNextLevel: Int = 100

    @Published var camposVisitados: Int = 0
    @Published var provinciasVisitadas: Int = 0
    @Published var diasConsecutivos: Int = 0

    @Published var dailyXP: Int = 0
    @Published var hasClaimedToday: Bool = false

    @Published var isLoading: Bool = false

    private init() {}

    func applyNotificationPayload(_ userInfo: [String: Any]) {
        if let v = userInfo["level"] as? Int { level = v }
        if let v = userInfo["xp"] as? Int { currentXP = v }
        if let v = userInfo["xpToNextLevel"] as? Int { xpToNextLevel = v }

        if let v = userInfo["camposVisitados"] as? Int { camposVisitados = v }
        if let v = userInfo["provinciasVisitadas"] as? Int { provinciasVisitadas = v }
        if let v = userInfo["diasConsecutivos"] as? Int { diasConsecutivos = v }

        if let v = userInfo["dailyXP"] as? Int { dailyXP = v }
        if let v = userInfo["hasClaimedToday"] as? Bool { hasClaimedToday = v }
    }

    @MainActor
    func loadInitialData(for userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Cargar nivel y XP
            let nivelResponse = try await supabase.from("niveles")
                .select("level, current_xp, xp_to_next_level")
                .eq("id_usuario", value: userId)
                .limit(1)
                .execute()

            if let nivelData = try? JSONSerialization.jsonObject(with: nivelResponse.data) as? [[String: Any]],
               let nivel = nivelData.first {
                level = nivel["level"] as? Int ?? 1
                currentXP = nivel["current_xp"] as? Int ?? 0
                xpToNextLevel = nivel["xp_to_next_level"] as? Int ?? 100
            }

            // 2. Cargar visitas y calcular estadísticas
            let visitasResponse = try await supabase.from("visitas")
                .select("id_campo, created_at")
                .eq("id_usuario", value: userId)
                .order("created_at", ascending: false)
                .execute()

            if let visitasData = try? JSONSerialization.jsonObject(with: visitasResponse.data) as? [[String: Any]] {
                // Campos únicos visitados
                let uniqueCampos = Set(visitasData.compactMap { $0["id_campo"] as? String })
                camposVisitados = uniqueCampos.count

                // Provincias visitadas
                if !uniqueCampos.isEmpty {
                    let provinciasResponse = try await supabase.from("campos")
                        .select("provincia")
                        .in("id", values: Array(uniqueCampos))
                        .execute()

                    if let provinciasData = try? JSONSerialization.jsonObject(with: provinciasResponse.data) as? [[String: Any]] {
                        provinciasVisitadas = Set(provinciasData.compactMap { $0["provincia"] as? String }).count
                    }
                }

                // Días consecutivos
                let fechasISO = visitasData.compactMap { $0["created_at"] as? String }
                diasConsecutivos = ProgressUtils.consecutiveDays(from: fechasISO)

                // Daily XP basado en días consecutivos
                dailyXP = ProgressUtils.dailyXP(for: diasConsecutivos)
            }

            // 3. Verificar si ya reclamó la recompensa hoy
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            let startOfDayISO = isoFormatter.string(from: startOfDay)

            let rewardsResponse = try await supabase.from("daily_rewards")
                .select("id")
                .eq("id_usuario", value: userId)
                .gte("claimed_at", value: startOfDayISO)
                .limit(1)
                .execute()

            if let rewardsData = try? JSONSerialization.jsonObject(with: rewardsResponse.data) as? [[String: Any]] {
                hasClaimedToday = !rewardsData.isEmpty
            }

            Logger.debug("✅ ProgressStore: Datos iniciales cargados - Level \(level), XP \(currentXP)/\(xpToNextLevel), Campos: \(camposVisitados), Provincias: \(provinciasVisitadas), Días: \(diasConsecutivos)")
        } catch {
            Logger.error("❌ ProgressStore: Error cargando datos iniciales - \(error.localizedDescription)")
        }
    }
}
