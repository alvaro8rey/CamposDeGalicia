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
            if let array = jsonObject as? [[String: Any]], !array.isEmpty {
                let dict = array[0]
                let newLevel = dict["level"] as? Int ?? 1
                let newCurrentXP = dict["current_xp"] as? Int ?? 0
                let newXPToNextLevel = dict["xp_to_next_level"] as? Int ?? 100

                if let lastUpdate = lastUpdatedFromNotification, Date().timeIntervalSince(lastUpdate) < 2 {
                    // Usa valores actuales si hay notificación reciente
                    Logger.debug("Usando valores de notificación reciente")
                } else {
                    level = newLevel
                    currentXP = newCurrentXP
                    xpToNextLevel = newXPToNextLevel
                }

                Logger.debug("Level data loaded: Level \(newLevel), XP \(newCurrentXP)/\(newXPToNextLevel)")
            } else {
                errorMessage = "Error: No se encontraron datos de nivel"
                level = 1
                currentXP = 0
                xpToNextLevel = 100
            }
        } catch {
            errorMessage = "Error al cargar datos de nivel: \(error.localizedDescription)"
            Logger.error("Error loading level data: \(error.localizedDescription)")
            level = 1
            currentXP = 0
            xpToNextLevel = 100
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
                    let dict = array[0]
                    if let distancia = dict["distancia_predeterminada"] as? Double {
                        distanciaPredeterminada = distancia
                    }
                } else {
                    errorMessage = L(.errorMultiplePreferences)
                    let dict = array[0]
                    if let distancia = dict["distancia_predeterminada"] as? Double {
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
               !array.isEmpty,
               let distancia = array[0]["distancia_predeterminada"] as? Double {
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
        await loadLevelData(for: userId)
        await loadAchievementsCount(for: userId)
        await loadVisitHistory(for: userId, campos: campos)
        await loadPreferences(for: userId)
    }
}
