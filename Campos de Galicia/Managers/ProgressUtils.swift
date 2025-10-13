import Foundation

enum ProgressUtils {
    static func dailyXP(for day: Int) -> Int {
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

    static func evaluate(condition: String, campos: Int, provincias: Int, dias: Int) -> Bool {
        let parts = condition.split(separator: ">=").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let target = Int(parts[1]) else { return false }

        if condition.contains("campos_visitados") { return campos >= target }
        if condition.contains("provincias_visitadas") { return provincias >= target }
        if condition.contains("dias_visitados") { return dias >= target }
        return false
    }

    static func nextLevel(from totalXP: Int, cap: Int) -> (level: Int, xpToNextLevel: Int) {
        var level = 1
        var next = 100
        while totalXP >= next && level < cap {
            level += 1
            next = level * 100
        }
        return (level, next)
    }

    static func consecutiveDays(from isoDates: [String]) -> Int {
        guard !isoDates.isEmpty else { return 0 }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        iso.timeZone = TimeZone(secondsFromGMT: 0)

        let dates = isoDates.compactMap { iso.date(from: $0) }.sorted(by: >)
        guard !dates.isEmpty else { return 0 }

        let cal = Calendar.current
        var streak = 1
        var current = cal.startOfDay(for: dates[0])

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
