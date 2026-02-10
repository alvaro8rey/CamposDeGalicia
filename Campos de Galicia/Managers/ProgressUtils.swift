import Foundation

enum ProgressUtils {
    /// Devuelve el XP de la recompensa diaria según el día del ciclo semanal (1-7).
    static func dailyXP(for cycleDay: Int) -> Int {
        switch cycleDay {
        case 1: return 20
        case 2: return 30
        case 3: return 40
        case 4: return 50
        case 5: return 70
        case 6: return 100
        case 7: return 150
        default: return 20
        }
    }

    /// Calcula el día del ciclo semanal (1-7) a partir de los días consecutivos totales.
    static func cycleDayFrom(consecutiveDays: Int) -> Int {
        guard consecutiveDays > 0 else { return 1 }
        return ((consecutiveDays - 1) % 7) + 1
    }

    static func evaluate(condition: String, campos: Int, provincias: Int, dias: Int, reseñas: Int = 0) -> Bool {
        let parts = condition.split(separator: ">=").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let target = Int(parts[1]) else { return false }

        if condition.contains("campos_visitados") { return campos >= target }
        if condition.contains("provincias_visitadas") { return provincias >= target }
        if condition.contains("dias_visitados") { return dias >= target }
        if condition.contains("reseñas_escritas") { return reseñas >= target }
        return false
    }

    static func consecutiveDays(from isoDates: [String]) -> Int {
        guard !isoDates.isEmpty else { return 0 }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        iso.timeZone = TimeZone(secondsFromGMT: 0)

        let dates = isoDates.compactMap { iso.date(from: $0) }.sorted(by: >)
        guard let firstDate = dates.first else { return 0 }

        let cal = Calendar.current
        var streak = 1
        var current = cal.startOfDay(for: firstDate)

        for i in 1..<dates.count {
            let prev = cal.startOfDay(for: dates[i])
            let diff = cal.dateComponents([.day], from: prev, to: current).day ?? 0
            if diff == 1 { streak += 1 }
            else if diff > 1 { break }
            current = prev
        }
        return streak
    }
}
