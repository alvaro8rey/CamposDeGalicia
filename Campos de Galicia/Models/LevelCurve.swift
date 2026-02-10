import Foundation

/// Curva de niveles compartida por toda la app.
/// - Definición:
///   - XP por nivel = basePerLevel + growthPerLevel * (nivel - 1)
///   - XP acumulada necesaria para *alcanzar* un nivel L (L>=1):
///       sum_{k=1..L-1} (base + growth*(k-1))
///     => 0 para nivel 1.
enum LevelCurve {
    // Ajusta estos dos valores a tu gusto:
    static let basePerLevel: Int = 100     // XP del nivel 1
    static let growthPerLevel: Int = 50    // Incremento de XP por nivel

    /// XP necesaria (acumulada) para alcanzar el nivel dado.
    /// Nivel 1 => 0
    static func xpNeededToReachLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        let n = level - 1
        // Sumatorio aritmético: n/2 * [2a + (n-1)d]
        return n * (2 * basePerLevel + (n - 1) * growthPerLevel) / 2
    }

    /// XP necesaria para completar el nivel actual (tamaño del tramo del nivel).
    static func xpSpanForLevel(_ level: Int) -> Int {
        return basePerLevel + (level - 1) * growthPerLevel
    }

    /// Devuelve (nivelActual, xpAcumuladaParaSiguienteNivel)
    /// - Sin nivel máximo: la curva crece indefinidamente.
    /// - xpAcumuladaParaSiguienteNivel es el umbral *acumulado* (para mostrar como denominador).
    static func levelAndNextThreshold(for totalXP: Int) -> (level: Int, nextThresholdXP: Int) {
        var level = 1
        // Subimos hasta que el siguiente umbral supere el totalXP.
        // La XP necesaria crece con cada nivel, así que el bucle termina para cualquier XP finito.
        while totalXP >= xpNeededToReachLevel(level + 1) {
            level += 1
        }
        let nextThreshold = xpNeededToReachLevel(level + 1)
        return (level, nextThreshold)
    }

    /// Progreso *dentro* del nivel actual: (xpActual - xpBaseDelNivel, xpNecesariaEnEsteNivel)
    static func inLevelProgress(for totalXP: Int, level: Int) -> (inLevelXP: Int, levelSpan: Int) {
        let base = xpNeededToReachLevel(level)
        let span = xpSpanForLevel(level)
        return (max(0, totalXP - base), span)
    }
}
