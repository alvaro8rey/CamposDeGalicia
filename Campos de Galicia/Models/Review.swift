import Foundation

/// Modelo para reseñas de campos
struct Review: Identifiable, Codable, Equatable {
    let id: Int?
    let campo_id: UUID
    let user_id: UUID
    let reseña: String
    let rating: Int
    let created_at: Date?
    let reviewer_name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case campo_id
        case user_id
        case reseña
        case rating
        case created_at
        case reviewer_name
    }

    // Computed property for display
    var displayName: String {
        reviewer_name ?? "Usuario"
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

    enum CodingKeys: String, CodingKey {
        case campo_id
        case user_id
        case reseña
        case rating
        case reviewer_name
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
