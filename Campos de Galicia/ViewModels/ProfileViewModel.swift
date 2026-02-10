import Foundation
import SwiftUI
import Supabase

/// Modelo de preferencias del usuario
struct Preferences: Codable {
    let id_usuario: String
    let distancia_predeterminada: Double
}

/// ViewModel para manejar la lógica del perfil del usuario
@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    // Level & XP
    @Published var level: Int = 1
    @Published var currentXP: Int = 0
    @Published var xpToNextLevel: Int = 100

    // Statistics
    @Published var camposVisitados: Int = 0
    @Published var totalAchievementsCount: Int = 0
    @Published var newAchievementsCount: Int = 0
    @Published var provinciasVisitadas: Int = 0
    @Published var diasConsecutivos: Int = 0
    @Published var reseñasEscritas: Int = 0

    // Achievements
    @Published var closestAchievement: Logro? = nil
    @Published var closestAchievementProgress: (current: Int, target: Int) = (0, 0)
    private var allLogros: [Logro] = []
    private var logrosDesbloqueados: Set<UUID> = []

    /// True si el usuario ha completado todos los logros (tiene el logro maestro)
    var allAchievementsCompleted: Bool {
        logrosDesbloqueados.contains(LevelManager.MASTER_ACHIEVEMENT_ID)
    }

    // Visit History
    @Published var historialCampos: [CampoModel] = []
    @Published var allVisits: [(campo: CampoModel, date: Date)] = []
    @Published var isLoadingHistorial: Bool = false

    // Preferences
    @Published var distanciaPredeterminada: Double = 10.0

    // Error messages
    @Published var errorMessage: String? = nil

    // MARK: - Private Properties
    private var lastUpdatedFromNotification: Date? = nil
    private var hasLoadedInitialData: Bool = false

    // MARK: - Initialization
    init() {
        Logger.debug("ProfileViewModel inicializado")
    }

    // MARK: - Level & XP Methods

    func loadLevelData(for userId: String) async {
        do {
            let response = try await supabase.from("niveles")
                .select("level, current_xp, xp_to_next_level")
                .eq("id_usuario", value: userId)
                .limit(1)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: response.data, options: [])
            if let array = jsonObject as? [[String: Any]],
               let dict = array.first {
                let newLevel = dict["level"] as? Int ?? 1
                let newCurrentXP = dict["current_xp"] as? Int ?? 0
                let newXPToNextLevel = dict["xp_to_next_level"] as? Int ?? 100

                if let lastUpdate = lastUpdatedFromNotification, Date().timeIntervalSince(lastUpdate) < 2 {
                    // Usa valores actuales si hay notificación reciente
                    Logger.debug("Usando valores de notificación reciente")
                } else {
                    // Solo actualizar si los valores han cambiado para evitar parpadeo
                    if level != newLevel || currentXP != newCurrentXP || xpToNextLevel != newXPToNextLevel {
                        level = newLevel
                        currentXP = newCurrentXP
                        xpToNextLevel = newXPToNextLevel
                    }
                }

                Logger.debug("Level data loaded: Level \(newLevel), XP \(newCurrentXP)/\(newXPToNextLevel)")
            } else {
                // Solo establecer valores por defecto si aún no se han cargado
                if !hasLoadedInitialData {
                    errorMessage = "Error: No se encontraron datos de nivel"
                    level = 1
                    currentXP = 0
                    xpToNextLevel = 100
                }
            }
        } catch {
            // Solo establecer valores por defecto si aún no se han cargado
            if !hasLoadedInitialData {
                errorMessage = "Error al cargar datos de nivel: \(error.localizedDescription)"
                Logger.error("Error loading level data: \(error.localizedDescription)")
                level = 1
                currentXP = 0
                xpToNextLevel = 100
            }
        }
    }

    func updateFromNotification() {
        lastUpdatedFromNotification = Date()
    }

    // MARK: - Achievements Methods

    func loadAchievementsCount(for userId: String) async {
        do {
            let response = try await supabase.from("logros_desbloqueados")
                .select("id")
                .eq("id_usuario", value: userId)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: response.data, options: [])
            guard let array = jsonObject as? [[String: Any]] else {
                errorMessage = "Error: Formato de datos de logros desbloqueados inesperado"
                return
            }

            let newTotalAchievements = array.count
            if newTotalAchievements > totalAchievementsCount {
                newAchievementsCount = newTotalAchievements - totalAchievementsCount
            }
            totalAchievementsCount = newTotalAchievements

            Logger.debug("Achievements loaded: \(totalAchievementsCount)")
        } catch {
            errorMessage = "Error al cargar conteo de logros: \(error.localizedDescription)"
            Logger.error("Error loading achievements: \(error.localizedDescription)")
        }
    }

    func resetNewAchievementsCount() {
        newAchievementsCount = 0
    }

    /// Carga todos los logros disponibles
    func loadAllAchievements() async {
        do {
            let response = try await supabase.from("logros")
                .select("id, nombre, descripcion, condicion, orden, xp")
                .execute()
            let decoder = JSONDecoder()
            allLogros = try decoder.decode([Logro].self, from: response.data)
            Logger.debug("Loaded \(allLogros.count) achievements")
        } catch {
            errorMessage = "Error al cargar logros: \(error.localizedDescription)"
            Logger.error("Error loading achievements: \(error.localizedDescription)")
        }
    }

    /// Carga los IDs de los logros desbloqueados por el usuario
    func loadUnlockedAchievements(for userId: String) async {
        do {
            let response = try await supabase.from("logros_desbloqueados")
                .select("id_logro")
                .eq("id_usuario", value: userId)
                .execute()
            let decoder = JSONDecoder()
            let array = try decoder.decode([[String: UUID]].self, from: response.data)
            logrosDesbloqueados = Set(array.compactMap { $0["id_logro"] })
            Logger.debug("Loaded \(logrosDesbloqueados.count) unlocked achievements")
        } catch {
            errorMessage = "Error al cargar logros desbloqueados: \(error.localizedDescription)"
            Logger.error("Error loading unlocked achievements: \(error.localizedDescription)")
        }
    }

    /// Carga estadísticas adicionales necesarias para calcular progreso de logros
    func loadAdditionalStats(for userId: String) async {
        do {
            // Cargar provincias visitadas
            let visitasResponse = try await supabase.from("visitas")
                .select("id_campo")
                .eq("id_usuario", value: userId)
                .limit(500)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: visitasResponse.data, options: [])
            if let array = jsonObject as? [[String: Any]] {
                let campoIds = Set(array.compactMap { $0["id_campo"] as? String })

                if !campoIds.isEmpty {
                    let camposResponse = try await supabase.from("campos")
                        .select("provincia")
                        .in("id", values: Array(campoIds))
                        .execute()
                    if let camposArr = try JSONSerialization.jsonObject(with: camposResponse.data) as? [[String: Any]] {
                        let uniqueProvincias = Set(camposArr.compactMap { $0["provincia"] as? String })
                        provinciasVisitadas = uniqueProvincias.count
                    }
                }
            }

            // Cargar reseñas escritas
            let reseñasResponse = try await supabase.from("reseñas")
                .select("id")
                .eq("user_id", value: userId)
                .limit(100)
                .execute()
            if let reseñasArr = try JSONSerialization.jsonObject(with: reseñasResponse.data) as? [[String: Any]] {
                reseñasEscritas = reseñasArr.count
            }

            // Cargar días consecutivos desde accesos_diarios
            let accesosResponse = try await supabase.from("accesos_diarios")
                .select("dias_consecutivos")
                .eq("id_usuario", value: userId)
                .execute()
            if let accesosArr = try JSONSerialization.jsonObject(with: accesosResponse.data) as? [[String: Any]],
               let firstAcceso = accesosArr.first,
               let dias = firstAcceso["dias_consecutivos"] as? Int {
                diasConsecutivos = dias
            }

            Logger.debug("Additional stats loaded: \(provinciasVisitadas) provincias, \(reseñasEscritas) reseñas, \(diasConsecutivos) días")
        } catch {
            errorMessage = "Error al cargar estadísticas: \(error.localizedDescription)"
            Logger.error("Error loading additional stats: \(error.localizedDescription)")
        }
    }

    /// Calcula el progreso de un logro específico
    private func calculateProgress(for logro: Logro) -> (current: Int, target: Int) {
        guard let condicion = logro.condicion else { return (0, 0) }

        if condicion.contains("campos_visitados") {
            let target = condicion.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(camposVisitados, target), target)
        }
        if condicion.contains("provincias_visitadas") {
            let target = condicion.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(provinciasVisitadas, target), target)
        }
        if condicion.contains("dias_visitados") {
            let target = condicion.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(diasConsecutivos, target), target)
        }
        if condicion.contains("reseñas_escritas") {
            let target = condicion.split(separator: ">=").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            return (min(reseñasEscritas, target), target)
        }
        return (0, 0)
    }

    /// Calcula y actualiza el logro más cercano a completar
    func updateClosestAchievement() {
        // Filtrar logros pendientes (no desbloqueados)
        let pendingLogros = allLogros.filter { !logrosDesbloqueados.contains($0.id) }

        guard !pendingLogros.isEmpty else {
            closestAchievement = nil
            closestAchievementProgress = (0, 0)
            return
        }

        // Calcular progreso para cada logro pendiente
        var bestLogro: Logro? = nil
        var bestProgress: Double = 0.0
        var bestProgressValues: (current: Int, target: Int) = (0, 0)

        for logro in pendingLogros {
            let (current, target) = calculateProgress(for: logro)
            guard target > 0 else { continue }

            let progress = Double(current) / Double(target)

            // Buscar el logro con mayor progreso (más cercano a completar)
            if progress > bestProgress || (progress == bestProgress && (logro.orden ?? Int.max) < (bestLogro?.orden ?? Int.max)) {
                bestProgress = progress
                bestLogro = logro
                bestProgressValues = (current, target)
            }
        }

        closestAchievement = bestLogro
        closestAchievementProgress = bestProgressValues

        if let achievement = bestLogro {
            Logger.debug("Closest achievement: \(achievement.nombre) - \(bestProgressValues.current)/\(bestProgressValues.target)")
        }
    }

    // MARK: - Visit History Methods

    func loadVisitHistory(for userId: String, campos: [CampoModel]) async {
        isLoadingHistorial = true
        defer { isLoadingHistorial = false }

        do {
            // Limitar a las últimas 100 visitas para mejor rendimiento
            let visitasResponse = try await supabase.from("visitas")
                .select("id_campo, created_at")
                .eq("id_usuario", value: userId)
                .order("created_at", ascending: false)
                .limit(100)
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

                historialCampos = Array(allVisits.map { $0.campo }.prefix(3))

                Logger.debug("Visit history loaded: \(camposVisitados) campos visitados")
            }
        } catch {
            errorMessage = "Error al cargar el historial: \(error.localizedDescription)"
            Logger.error("Error loading visit history: \(error.localizedDescription)")
        }
    }

    // MARK: - Preferences Methods

    func loadPreferences(for userId: String) async {
        do {
            let preferenciasResponse = try await supabase.from("preferencias")
                .select("id_usuario, distancia_predeterminada")
                .eq("id_usuario", value: userId)
                .execute()

            let jsonObject = try JSONSerialization.jsonObject(with: preferenciasResponse.data, options: [])
            if let array = jsonObject as? [[String: Any]] {
                if array.isEmpty {
                    // Create default preference
                    let preferences = Preferences(id_usuario: userId, distancia_predeterminada: 10.0)
                    do {
                        _ = try await supabase.from("preferencias").insert(preferences).execute()
                        distanciaPredeterminada = 10.0
                    } catch {
                        if !error.localizedDescription.contains("duplicate key value") {
                            errorMessage = "Error al crear preferencias: \(error.localizedDescription)"
                        }
                        await fallbackLoadPreferences(userId)
                    }
                } else if array.count == 1 {
                    if let dict = array.first,
                       let distancia = dict["distancia_predeterminada"] as? Double {
                        distanciaPredeterminada = distancia
                    }
                } else {
                    errorMessage = L(.errorMultiplePreferences)
                    if let dict = array.first,
                       let distancia = dict["distancia_predeterminada"] as? Double {
                        distanciaPredeterminada = distancia
                    }
                }
            }

            Logger.debug("Preferences loaded: \(distanciaPredeterminada)km")
        } catch {
            errorMessage = "Error al cargar preferencias: \(error.localizedDescription)"
            Logger.error("Error loading preferences: \(error.localizedDescription)")
            await fallbackLoadPreferences(userId)
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
               let firstItem = array.first,
               let distancia = firstItem["distancia_predeterminada"] as? Double {
                distanciaPredeterminada = distancia
            }
        } catch {
            Logger.error("Fallback load preferences failed: \(error.localizedDescription)")
        }
    }

    func savePreferences(for userId: String) async {
        do {
            let preferences = Preferences(id_usuario: userId, distancia_predeterminada: distanciaPredeterminada)
            _ = try await supabase.from("preferencias").upsert(preferences).execute()
            Logger.success("✅ Preferencias guardadas: \(distanciaPredeterminada)km")
        } catch {
            errorMessage = "Error al guardar preferencias: \(error.localizedDescription)"
            Logger.error("Error saving preferences: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Carga todos los datos del perfil
    func loadAllData(for userId: String, campos: [CampoModel]) async {
        // Solo cargar datos si no se han cargado antes
        guard !hasLoadedInitialData else { return }

        await loadLevelData(for: userId)
        await loadAchievementsCount(for: userId)
        await loadVisitHistory(for: userId, campos: campos)
        await loadPreferences(for: userId)
        await loadAllAchievements()
        await loadUnlockedAchievements(for: userId)
        await loadAdditionalStats(for: userId)
        updateClosestAchievement()

        hasLoadedInitialData = true
    }

    /// Fuerza la recarga de todos los datos (útil después de cambios)
    func forceReloadAllData(for userId: String, campos: [CampoModel]) async {
        await loadLevelData(for: userId)
        await loadAchievementsCount(for: userId)
        await loadVisitHistory(for: userId, campos: campos)
        await loadPreferences(for: userId)
        await loadAllAchievements()
        await loadUnlockedAchievements(for: userId)
        await loadAdditionalStats(for: userId)
        updateClosestAchievement()
    }
}
