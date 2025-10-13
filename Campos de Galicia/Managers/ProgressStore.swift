import Foundation
import Combine

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
}
