import Foundation

/// Modelo para reseñas de campos
struct Review: Identifiable, Codable, Equatable {
    let id: Int?
    let campo_id: UUID
    let user_id: UUID
    let reseña: String
    let rating: Int
    let created_at: Date?
    let updated_at: Date?
    let reviewer_name: String?
    let fotos: [String]?
    let is_anonymous: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case campo_id
        case user_id
        case reseña
        case rating
        case created_at
        case updated_at
        case reviewer_name
        case fotos
        case is_anonymous
    }

    var isEdited: Bool {
        guard let created = created_at, let updated = updated_at else {
            return false
        }
        return updated.timeIntervalSince(created) > 60 // Más de 1 minuto de diferencia
    }

    // Computed property for display
    var displayName: String {
        if is_anonymous == true {
            return "Anónimo"
        }
        return reviewer_name ?? "Usuario"
    }

    var formattedDate: String {
        guard let date = created_at else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// DTO para crear nuevas reseñas
struct ReviewCreate: Codable {
    let campo_id: String
    let user_id: String
    let reseña: String
    let rating: Int
    let reviewer_name: String
    let fotos: [String]?
    let is_anonymous: Bool

    enum CodingKeys: String, CodingKey {
        case campo_id
        case user_id
        case reseña
        case rating
        case reviewer_name
        case fotos
        case is_anonymous
    }
}

/// Estadísticas de reseñas para un campo
struct ReviewStats {
    let averageRating: Double
    let totalReviews: Int
    let ratingDistribution: [Int: Int] // Rating -> Count

    var hasReviews: Bool {
        totalReviews > 0
    }

    var formattedAverage: String {
        String(format: "%.1f", averageRating)
    }
}

/// Tipo de ordenación para reseñas
enum ReviewSortType: String, CaseIterable, Identifiable {
    case recent = "Más recientes"
    case oldest = "Más antiguas"
    case highest = "Mejor valoradas"
    case lowest = "Peor valoradas"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .recent: return "clock.arrow.circlepath"
        case .oldest: return "clock"
        case .highest: return "star.fill"
        case .lowest: return "star"
        }
    }
}
