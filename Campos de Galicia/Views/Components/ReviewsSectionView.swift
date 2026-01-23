import SwiftUI

/// Sección completa de reseñas para integrar en CampoDetalleView
struct ReviewsSectionView: View {
    let campoId: UUID
    let campoNombre: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var reviewsManager = ReviewsManager()

    @State private var showAddReview: Bool = false
    @State private var showAllReviews: Bool = false
    @State private var reviewToEdit: Review?
    @State private var canUserReview: Bool = true

    private let maxFeaturedReviews = 5

    var featuredReviews: [Review] {
        // Mostrar las 5 mejores reseñas ordenadas por:
        // 1. Nivel del usuario (más alto primero) - usuarios VIP tienen prioridad
        // 2. Rating (más alto primero)
        // 3. Fecha (más reciente primero)
        return reviewsManager.reviews
            .sorted { review1, review2 in
                // Primero por nivel del usuario
                let level1 = review1.reviewer_level ?? 1
                let level2 = review2.reviewer_level ?? 1
                if level1 != level2 {
                    return level1 > level2
                }

                // Luego por rating
                if review1.rating != review2.rating {
                    return review1.rating > review2.rating
                }

                // Finalmente por fecha
                return (review1.created_at ?? Date.distantPast) > (review2.created_at ?? Date.distantPast)
            }
            .prefix(maxFeaturedReviews)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // HEADER - Clickeable para abrir modal (estilo App Store)
            Button(action: {
                if reviewsManager.stats.hasReviews {
                    showAllReviews = true
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Valoraciones y reseñas")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        if reviewsManager.stats.hasReviews {
                            HStack(spacing: 6) {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { index in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }
                                }

                                Text(reviewsManager.stats.formattedAverage)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Text("· \(reviewsManager.stats.totalReviews) \(reviewsManager.stats.totalReviews == 1 ? "valoración" : "valoraciones")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Sin valoraciones todavía")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if reviewsManager.stats.hasReviews {
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // SLIDER DE RESEÑAS DESTACADAS
            if !reviewsManager.reviews.isEmpty && !featuredReviews.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(featuredReviews) { review in
                            CompactReviewCardView(review: review)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // BOTÓN GRANDE PARA VALORAR
            if authViewModel.isAuthenticated {
                if canUserReview {
                    Button(action: {
                        showAddReview = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16))

                            Text("Escribir una reseña")
                                .font(.callout)
                                .fontWeight(.medium)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    // Ya dejó una reseña - mostrar botón para editar
                    if let userReview = reviewsManager.reviews.first(where: { $0.user_id == authViewModel.user?.id }) {
                        Button(action: {
                            reviewToEdit = userReview
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16))

                                Text("Editar mi reseña")
                                    .font(.callout)
                                    .fontWeight(.medium)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                // Not authenticated
                NotAuthenticatedReviewView()
                    .padding(.horizontal)
            }

            // Loading / Error / Empty States
            if reviewsManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Cargando reseñas...")
                    Spacer()
                }
                .padding(40)
            } else if let errorMessage = reviewsManager.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await loadReviews() }
                }
                .padding(.horizontal)
            } else if reviewsManager.reviews.isEmpty {
                EmptyReviewsView()
                    .padding(.horizontal)
            }
        }
        .onAppear {
            Task { await loadReviews() }
        }
        .sheet(isPresented: $showAddReview) {
            AddReviewView(
                campoId: campoId,
                campoNombre: campoNombre,
                onReviewAdded: {
                    Task {
                        await loadReviews()
                        await checkIfUserCanReview()
                    }
                }
            )
            .environmentObject(authViewModel)
        }
        .sheet(item: $reviewToEdit) { review in
            AddReviewView(
                campoId: campoId,
                campoNombre: campoNombre,
                existingReview: review,
                onReviewAdded: {
                    Task {
                        await loadReviews()
                        await checkIfUserCanReview()
                    }
                    reviewToEdit = nil
                }
            )
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showAllReviews) {
            AllReviewsModalView(
                reviews: reviewsManager.reviews,
                stats: reviewsManager.stats,
                currentUserId: authViewModel.user?.id,
                onEdit: { review in
                    showAllReviews = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        reviewToEdit = review
                    }
                },
                onDelete: { review in
                    Task {
                        await deleteReview(review)
                    }
                }
            )
        }
        .onChange(of: showAllReviews) { isShowing in
            // Recargar reseñas cuando se cierra el modal
            if !isShowing {
                Task {
                    await loadReviews()
                }
            }
        }
    }

    // MARK: - Methods
    private func loadReviews() async {
        await reviewsManager.fetchReviews(for: campoId)
        await checkIfUserCanReview()
    }

    private func checkIfUserCanReview() async {
        guard let userId = authViewModel.user?.id else {
            canUserReview = false
            return
        }

        canUserReview = await reviewsManager.canUserReview(userId: userId, campoId: campoId)
    }

    private func deleteReview(_ review: Review) async {
        guard let reviewId = review.id,
              let userId = authViewModel.user?.id else {
            return
        }

        let success = await reviewsManager.deleteReview(reviewId, userId: userId)
        if success {
            // Review already removed from array by manager
            Logger.success("Reseña eliminada")
            // Actualizar el estado de canUserReview
            await checkIfUserCanReview()
        }
    }
}

/// Vista cuando el usuario no está autenticado
struct NotAuthenticatedReviewView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Inicia sesión para opinar")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Comparte tu experiencia con la comunidad")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Vista cuando el usuario ya dejó una reseña
struct AlreadyReviewedView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Ya dejaste tu opinión")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Solo puedes dejar una reseña por campo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Vista de error con retry
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Reintentar")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.orange)
                .cornerRadius(10)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

