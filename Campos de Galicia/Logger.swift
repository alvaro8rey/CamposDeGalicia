import Foundation

/// Sistema de logging simple para controlar la salida de debug en producción
enum Logger {
    /// Controla si el logging está habilitado (true en debug, false en producción)
    #if DEBUG
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif

    /// Niveles de logging
    enum Level: String {
        case debug = "🔧"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
    }

    /// Log genérico con nivel
    static func log(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }

        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        print("\(level.rawValue) [\(timestamp)] [\(fileName):\(line)] \(message)")
    }

    /// Métodos de conveniencia
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    static func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, file: file, function: function, line: line)
    }
}
