import Foundation
import Supabase

/// Manager para manejar operaciones de reseñas
@MainActor
class ReviewsManager: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var stats: ReviewStats = ReviewStats(averageRating: 0, totalReviews: 0, ratingDistribution: [:])
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var distinguishedUserIds: Set<UUID> = []

    // MARK: - Fetch Reviews
    func fetchReviews(for campoId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. Obtener reseñas sin niveles (últimas 50 para mejor rendimiento)
            let response = try await supabase.from("reseñas")
                .select("*")
                .eq("campo_id", value: campoId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Decodificar reseñas (reviewer_level será nil por ahora)
            let tempReviews = try decoder.decode([Review].self, from: response.data)

            // 2. Obtener user_ids únicos de las reseñas
            let uniqueUserIds = Set(tempReviews.map { $0.user_id.uuidString })

            // 3. Obtener niveles de esos usuarios
            struct UserLevel: Codable {
                let id_usuario: String
                let level: Int
            }

            let levelsResponse = try await supabase.from("niveles")
                .select("id_usuario, level")
                .in("id_usuario", values: Array(uniqueUserIds))
                .execute()

            let userLevels = try decoder.decode([UserLevel].self, from: levelsResponse.data)

            // Crear diccionario de user_id -> level (lowercase para coincidir con UUID)
            let levelsDictionary = Dictionary(uniqueKeysWithValues: userLevels.map { ($0.id_usuario.lowercased(), $0.level) })

            // 4. Obtener perfiles de esos usuarios (para nombre y avatar)
            struct UserProfile: Codable {
                let id: String
                let nombre: String?
                let apellidos: String?
                let avatar_url: String?
            }

            let profilesResponse = try await supabase.from("perfiles")
                .select("id, nombre, apellidos, avatar_url")
                .in("id", values: Array(uniqueUserIds))
                .execute()

            let userProfiles = try decoder.decode([UserProfile].self, from: profilesResponse.data)

            // Crear diccionario de user_id -> profile (lowercase para coincidir con UUID)
            let profilesDictionary = Dictionary(uniqueKeysWithValues: userProfiles.map { ($0.id.lowercased(), $0) })

            // 5. Obtener usuarios destacados (con logro maestro desbloqueado)
            struct MasterUnlock: Codable {
                let id_usuario: UUID
            }
            let masterResp = try await supabase.from("logros_desbloqueados")
                .select("id_usuario")
                .eq("id_logro", value: LevelManager.MASTER_ACHIEVEMENT_ID.uuidString)
                .in("id_usuario", values: Array(uniqueUserIds))
                .execute()
            let masterUnlocks = (try? decoder.decode([MasterUnlock].self, from: masterResp.data)) ?? []
            distinguishedUserIds = Set(masterUnlocks.map { $0.id_usuario })

            // 6. Mapear niveles y perfiles a las reseñas usando tipo seguro (Codable)
            reviews = tempReviews.map { review in
                // Obtener nivel del usuario (default a 1 si no existe)
                let userKey = review.user_id.uuidString.lowercased()
                let level = levelsDictionary[userKey] ?? 1

                // Obtener perfil del usuario para datos actualizados
                let profile = profilesDictionary[userKey]

                // Construir nombre completo desde perfil si está disponible
                var reviewerName = review.reviewer_name ?? "Usuario"
                if let profile = profile {
                    let fullName = "\(profile.nombre ?? "") \(profile.apellidos ?? "")".trimmingCharacters(in: .whitespaces)
                    if !fullName.isEmpty {
                        reviewerName = fullName
                    }
                }

                // Usar avatar del perfil (siempre el más actualizado)
                let avatarUrl = profile?.avatar_url ?? review.reviewer_avatar_url

                // Crear nueva instancia de Review con datos actualizados
                // Orden de parámetros debe coincidir con el struct Review
                return Review(
                    id: review.id,
                    campo_id: review.campo_id,
                    user_id: review.user_id,
                    reseña: review.reseña,
                    rating: review.rating,
                    created_at: review.created_at,
                    updated_at: review.updated_at,
                    reviewer_name: reviewerName,
                    reviewer_avatar_url: avatarUrl,
                    reviewer_level: level,
                    fotos: review.fotos,
                    is_anonymous: review.is_anonymous
                )
            }

            // Calculate stats
            calculateStats()

            Logger.debug("✅ Cargadas \(reviews.count) reseñas con niveles")
        } catch {
            errorMessage = L(.errorLoadingReviews, error.localizedDescription)
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
            Logger.debug("🔍 Verificando si usuario puede reseñar...")
            Logger.debug("   Usuario ID: \(userId.uuidString)")
            Logger.debug("   Campo ID: \(campoId.uuidString)")

            struct ReviewIdCheck: Codable {
                let id: Int
            }

            // 1. Verificar que el usuario no haya dejado ya una reseña
            let reviewResponse = try await supabase.from("reseñas")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("campo_id", value: campoId.uuidString)
                .execute()

            let decoder = JSONDecoder()
            let existingReviews = try decoder.decode([ReviewIdCheck].self, from: reviewResponse.data)

            Logger.debug("   Reseñas existentes: \(existingReviews.count)")

            // Si ya hay una reseña, no puede dejar otra
            if !existingReviews.isEmpty {
                Logger.debug("❌ Usuario ya dejó una reseña en este campo")
                return false
            }

            // 2. Verificar que el usuario haya visitado el campo
            struct VisitCheck: Codable {
                let id: Int // El id de visitas es Int, no UUID
            }

            Logger.debug("🔍 Consultando tabla visitas...")
            let visitResponse = try await supabase.from("visitas")
                .select("id")
                .eq("id_usuario", value: userId.uuidString)
                .eq("id_campo", value: campoId.uuidString)
                .execute()

            // Log raw response
            let responseString = String(data: visitResponse.data, encoding: .utf8) ?? "N/A"
            Logger.debug("   Respuesta raw de visitas: \(responseString)")

            let visits = try decoder.decode([VisitCheck].self, from: visitResponse.data)

            Logger.debug("   Visitas encontradas: \(visits.count)")

            // Solo puede reseñar si ha visitado el campo
            if visits.isEmpty {
                Logger.debug("❌ Usuario no ha visitado este campo")
                return false
            }

            Logger.debug("✅ Usuario puede dejar reseña (ha visitado y no ha reseñado)")
            return true

        } catch {
            Logger.error("❌ Error checking if user can review: \(error.localizedDescription)")
            Logger.error("   Error completo: \(error)")
            return false
        }
    }

    // MARK: - Update Review
    func updateReview(_ reviewId: Int, userId: UUID, text: String, rating: Int, fotos: [String]?, isAnonymous: Bool) async -> Bool {
        do {
            Logger.debug("🔄 Actualizando reseña ID: \(reviewId) para usuario: \(userId.uuidString)")
            Logger.debug("📝 Nuevo contenido: \(text.prefix(50))...")
            Logger.debug("⭐ Nuevo rating: \(rating)")

            // Construir el update usando Codable para asegurar type safety
            struct ReviewUpdate: Codable {
                let reseña: String
                let rating: Int
                let fotos: [String]?
                let is_anonymous: Bool
            }

            let update = ReviewUpdate(
                reseña: text,
                rating: rating,
                fotos: fotos,
                is_anonymous: isAnonymous
            )

            // Pasar el struct directamente (Supabase lo codifica internamente)
            let response = try await supabase.from("reseñas")
                .update(update)
                .eq("id", value: reviewId)
                .eq("user_id", value: userId.uuidString.lowercased())
                .select()
                .execute()

            let responseString = String(data: response.data, encoding: .utf8) ?? "N/A"
            Logger.debug("📦 Respuesta de Supabase: \(responseString)")

            // Intentar decodificar la respuesta
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let updatedReviews = try decoder.decode([Review].self, from: response.data)

            guard let updatedReview = updatedReviews.first else {
                Logger.error("❌ No se encontró ninguna reseña con ID: \(reviewId)")
                errorMessage = L(.errorCouldNotUpdateReview)
                return false
            }

            Logger.success("✅ Reseña actualizada en la base de datos")
            Logger.debug("✅ Nueva reseña: \(updatedReview.reseña.prefix(30))...")

            // Actualizar el array local para reflejar cambios inmediatamente
            if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                await fetchReviews(for: reviews[index].campo_id)
            }

            return true
        } catch {
            errorMessage = L(.errorUpdatingReview, error.localizedDescription)
            Logger.error("❌ Error updating review: \(error.localizedDescription)")
            Logger.error("❌ Error details: \(error)")
            return false
        }
    }

    // MARK: - Delete Review (Admin or Owner)
    func deleteReview(_ reviewId: Int, userId: UUID) async -> Bool {
        do {
            _ = try await supabase.from("reseñas")
                .delete()
                .eq("id", value: reviewId)
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()

            // Remove from local array
            reviews.removeAll { $0.id == reviewId }
            calculateStats()

            Logger.success("✅ Reseña eliminada")
            return true
        } catch {
            errorMessage = L(.errorDeletingReview, error.localizedDescription)
            Logger.error("Error deleting review: \(error.localizedDescription)")
            return false
        }
    }
}
