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
            // 1. Obtener reseñas sin niveles
            let response = try await supabase.from("reseñas")
                .select("*")
                .eq("campo_id", value: campoId.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Decodificar reseñas (reviewer_level será nil por ahora)
            var tempReviews = try decoder.decode([Review].self, from: response.data)

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

            // Crear diccionario de user_id -> level
            let levelsDictionary = Dictionary(uniqueKeysWithValues: userLevels.map { ($0.id_usuario, $0.level) })

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

            // Crear diccionario de user_id -> profile
            let profilesDictionary = Dictionary(uniqueKeysWithValues: userProfiles.map { ($0.id, $0) })

            // 5. Mapear niveles y perfiles a las reseñas usando JSON manipulation
            let json = try JSONSerialization.jsonObject(with: response.data, options: [])
            guard let reviewsArray = json as? [[String: Any]] else {
                throw NSError(domain: "ReviewsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Formato de datos incorrecto"])
            }

            reviews = reviewsArray.compactMap { dict -> Review? in
                var mutableDict = dict

                if let userIdStr = dict["user_id"] as? String {
                    // Agregar nivel del usuario si existe
                    if let level = levelsDictionary[userIdStr] {
                        mutableDict["reviewer_level"] = level
                    } else {
                        mutableDict["reviewer_level"] = 1 // Nivel por defecto
                    }

                    // Siempre usar datos de perfiles para nombre y avatar (son los más actualizados)
                    if let profile = profilesDictionary[userIdStr] {
                        let fullName = "\(profile.nombre ?? "") \(profile.apellidos ?? "")".trimmingCharacters(in: .whitespaces)

                        // Usar nombre de perfil si está disponible, sino mantener el guardado en reviewer_name
                        if !fullName.isEmpty {
                            mutableDict["reviewer_name"] = fullName
                        } else if dict["reviewer_name"] == nil || (dict["reviewer_name"] as? String)?.isEmpty == true {
                            mutableDict["reviewer_name"] = "Usuario"
                        }

                        // Usar avatar de perfil (siempre el más actualizado)
                        mutableDict["reviewer_avatar_url"] = profile.avatar_url
                    }
                }

                do {
                    let reviewData = try JSONSerialization.data(withJSONObject: mutableDict)
                    return try decoder.decode(Review.self, from: reviewData)
                } catch {
                    Logger.error("Error decodificando reseña: \(error)")
                    return nil
                }
            }

            // Calculate stats
            calculateStats()

            Logger.debug("✅ Cargadas \(reviews.count) reseñas con niveles")
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

            // Construir el JSON manualmente para asegurar los tipos correctos
            let updateDict: [String: Any] = [
                "reseña": text,
                "rating": rating,
                "fotos": fotos as Any,
                "is_anonymous": isAnonymous
            ]

            let updateData = try JSONSerialization.data(withJSONObject: updateDict)

            // Realizar UPDATE con select para obtener la fila actualizada
            let response = try await supabase.from("reseñas")
                .update(updateData)
                .eq("id", value: reviewId)
                .select()
                .execute()

            let responseString = String(data: response.data, encoding: .utf8) ?? "N/A"
            Logger.debug("📦 Respuesta de Supabase: \(responseString)")

            // Intentar decodificar la respuesta
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let updatedReviews = try decoder.decode([Review].self, from: response.data)

            if updatedReviews.isEmpty {
                Logger.error("❌ No se encontró ninguna reseña con ID: \(reviewId)")
                errorMessage = "No se pudo actualizar la reseña"
                return false
            }

            Logger.success("✅ Reseña actualizada en la base de datos")
            Logger.debug("✅ Nueva reseña: \(updatedReviews[0].reseña.prefix(30))...")

            // Actualizar el array local para reflejar cambios inmediatamente
            if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                await fetchReviews(for: reviews[index].campo_id)
            }

            return true
        } catch {
            errorMessage = "Error al actualizar reseña: \(error.localizedDescription)"
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
