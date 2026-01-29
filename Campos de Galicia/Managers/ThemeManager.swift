import Foundation
import SwiftUI

/// Temas soportados
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Claro"
        case .dark: return "Oscuro"
        case .system: return "Sistema"
        }
    }

    var displayNameGalician: String {
        switch self {
        case .light: return "Claro"
        case .dark: return "Escuro"
        case .system: return "Sistema"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// Manager de tema centralizado
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
            objectWillChange.send()
        }
    }

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "app_theme") ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .system
    }

    /// Obtiene el ColorScheme actual
    nonisolated func getColorScheme() -> ColorScheme? {
        let savedTheme = UserDefaults.standard.string(forKey: "app_theme") ?? AppTheme.system.rawValue
        let theme = AppTheme(rawValue: savedTheme) ?? .system
        return theme.colorScheme
    }
}

// MARK: - SwiftUI Extension

extension View {
    /// Aplica el tema actual del ThemeManager
    func withTheme() -> some View {
        self.environmentObject(ThemeManager.shared)
    }
}
