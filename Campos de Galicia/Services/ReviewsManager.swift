import Foundation
import Supabase

/// Manager para manejar operaciones de reseñas
@MainActor
class ReviewsManager: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var stats: ReviewStats = ReviewStats(averageRating: 0, totalReviews: 0, ratingDistribution: [:])
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Fetch Reviews
    func fetchReviews(for campoId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.from("reseñas")
                .select("*")
                .eq("campo_id", value: campoId.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .useDefaultKeys

            reviews = try decoder.decode([Review].self, from: response.data)

            // Calculate stats
            calculateStats()

            Logger.debug("✅ Cargadas \(reviews.count) reseñas")
        } catch {
            errorMessage = "Error al cargar reseñas: \(error.localizedDescription)"
            Logger.error("Error loading reviews: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Calculate Stats
    private func calculateStats() {
        guard !reviews.isEmpty else {
            stats = ReviewStats(averageRating: 0, totalReviews: 0, ratingDistribution: [:])
            return
        }

        let totalReviews = reviews.count
        let sumRatings = reviews.reduce(0) { $0 + $1.rating }
        let averageRating = Double(sumRatings) / Double(totalReviews)

        var distribution: [Int: Int] = [:]
        for review in reviews {
            distribution[review.rating, default: 0] += 1
        }

        stats = ReviewStats(
            averageRating: averageRating,
            totalReviews: totalReviews,
            ratingDistribution: distribution
        )
    }

    // MARK: - Check if User Can Review
    func canUserReview(userId: UUID, campoId: UUID) async -> Bool {
        do {
            struct ReviewIdCheck: Codable {
                let id: Int
            }

            let response = try await supabase.from("reseñas")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("campo_id", value: campoId.uuidString)
                .execute()

            let decoder = JSONDecoder()
            let existingReviews = try decoder.decode([ReviewIdCheck].self, from: response.data)

            // User can only review once per campo
            return existingReviews.isEmpty
        } catch {
            Logger.error("Error checking if user can review: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Update Review
    func updateReview(_ reviewId: Int, userId: UUID, text: String, rating: Int, fotos: [String]?, isAnonymous: Bool) async -> Bool {
        do {
            struct ReviewUpdate: Codable {
                let reseña: String
                let rating: Int
                let fotos: [String]?
                let is_anonymous: Bool
                let updated_at: String
            }

            let update = ReviewUpdate(
                reseña: text,
                rating: rating,
                fotos: fotos,
                is_anonymous: isAnonymous,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            _ = try await supabase.from("reseñas")
                .update(update)
                .eq("id", value: reviewId)
                .eq("user_id", value: userId.uuidString)
                .execute()

            Logger.success("✅ Reseña actualizada")
            return true
        } catch {
            errorMessage = "Error al actualizar reseña: \(error.localizedDescription)"
            Logger.error("Error updating review: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Delete Review (Admin or Owner)
    func deleteReview(_ reviewId: Int, userId: UUID) async -> Bool {
        do {
            _ = try await supabase.from("reseñas")
                .delete()
                .eq("id", value: reviewId)
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Remove from local array
            reviews.removeAll { $0.id == reviewId }
            calculateStats()

            Logger.success("✅ Reseña eliminada")
            return true
        } catch {
            errorMessage = "Error al eliminar reseña: \(error.localizedDescription)"
            Logger.error("Error deleting review: \(error.localizedDescription)")
            return false
        }
    }
}
