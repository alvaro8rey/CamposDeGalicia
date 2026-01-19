import SwiftUI

/// Card moderna para mostrar reseñas de campos
struct ReviewCardView: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar + Name + Rating
            HStack(alignment: .top, spacing: 12) {
                // Avatar Circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Text(review.displayName.prefix(1).uppercased())
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(review.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        // Star Rating
                        StarRatingView(rating: review.rating, size: 14, color: .orange)
                    }

                    Text(review.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Review Text
            Text(review.reseña)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

/// Vista compacta para resumen de rating
struct RatingSummaryView: View {
    let stats: ReviewStats

    var body: some View {
        VStack(spacing: 12) {
            if stats.hasReviews {
                // Average Rating
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text(stats.formattedAverage)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.orange)

                        StarRatingView(
                            rating: Int(stats.averageRating.rounded()),
                            size: 16,
                            color: .orange
                        )

                        Text("\(stats.totalReviews) \(stats.totalReviews == 1 ? "reseña" : "reseñas")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 120)

                    Divider()
                        .frame(height: 80)

                    // Rating Distribution
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach((1...5).reversed(), id: \.self) { rating in
                            RatingBarView(
                                rating: rating,
                                count: stats.ratingDistribution[rating] ?? 0,
                                total: stats.totalReviews
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: Color.orange.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                EmptyReviewsView()
            }
        }
    }
}

/// Barra individual de distribución de rating
struct RatingBarView: View {
    let rating: Int
    let count: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(rating)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 12)

            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundColor(.orange)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

/// Vista de estrellas para rating
struct StarRatingView: View {
    let rating: Int
    let size: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(index <= rating ? color : Color.gray.opacity(0.3))
            }
        }
    }
}

/// Vista vacía cuando no hay reseñas
struct EmptyReviewsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.3))

            Text("Sin reseñas todavía")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Sé el primero en dejar tu opinión")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Preview
struct ReviewCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ReviewCardView(
                review: Review(
                    id: 1,
                    campo_id: UUID(),
                    user_id: UUID(),
                    reseña: "Excelente campo, bien cuidado y con buenas instalaciones. El césped está en perfecto estado.",
                    rating: 5,
                    created_at: Date().addingTimeInterval(-86400),
                    reviewer_name: "Juan García"
                )
            )

            ReviewCardView(
                review: Review(
                    id: 2,
                    campo_id: UUID(),
                    user_id: UUID(),
                    reseña: "Buen campo pero las gradas necesitan mejoras.",
                    rating: 3,
                    created_at: Date().addingTimeInterval(-172800),
                    reviewer_name: "María López"
                )
            )

            RatingSummaryView(
                stats: ReviewStats(
                    averageRating: 4.5,
                    totalReviews: 12,
                    ratingDistribution: [5: 7, 4: 3, 3: 1, 2: 1, 1: 0]
                )
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
