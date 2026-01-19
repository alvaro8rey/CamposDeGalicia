import SwiftUI

/// Sección completa de reseñas para integrar en CampoDetalleView
struct ReviewsSectionView: View {
    let campoId: UUID
    let campoNombre: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var reviewsManager = ReviewsManager()

    @State private var showAddReview: Bool = false
    @State private var canUserReview: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reseñas")
                        .font(.system(size: 24, weight: .bold))

                    if reviewsManager.stats.hasReviews {
                        Text("\(reviewsManager.stats.totalReviews) opiniones")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Add Review Button (only if authenticated and can review)
                if authViewModel.isAuthenticated && canUserReview {
                    Button(action: { showAddReview = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Opinar")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal)

            // Rating Summary
            if reviewsManager.stats.hasReviews {
                RatingSummaryView(stats: reviewsManager.stats)
                    .padding(.horizontal)
            }

            // Reviews List or Empty State
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
            } else {
                VStack(spacing: 12) {
                    ForEach(reviewsManager.reviews) { review in
                        ReviewCardView(review: review)
                            .contextMenu {
                                if review.user_id == authViewModel.user?.id {
                                    Button(role: .destructive) {
                                        Task { await deleteReview(review) }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }

            // Not Authenticated Message
            if !authViewModel.isAuthenticated {
                NotAuthenticatedReviewView()
                    .padding(.horizontal)
            } else if !canUserReview {
                AlreadyReviewedView()
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

// MARK: - Preview
struct ReviewsSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            ReviewsSectionView(
                campoId: UUID(),
                campoNombre: "Campo Municipal"
            )
            .environmentObject(AuthViewModel.shared)
        }
    }
}
