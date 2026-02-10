import SwiftUI

/// Modal fullscreen para mostrar todas las reseñas (estilo App Store)
struct AllReviewsModalView: View {
    let reviews: [Review]
    let stats: ReviewStats
    let currentUserId: UUID?
    let onEdit: ((Review) -> Void)?
    let onDelete: ((Review) -> Void)?
    var distinguishedUserIds: Set<UUID> = []

    @Environment(\.dismiss) var dismiss
    @State private var sortType: ReviewSortType = .recent

    var sortedReviews: [Review] {
        switch sortType {
        case .recent:
            // Usuarios destacados primero, luego por fecha
            return reviews.sorted { r1, r2 in
                let d1 = distinguishedUserIds.contains(r1.user_id)
                let d2 = distinguishedUserIds.contains(r2.user_id)
                if d1 != d2 { return d1 }
                let l1 = r1.reviewer_level ?? 1
                let l2 = r2.reviewer_level ?? 1
                if l1 != l2 { return l1 > l2 }
                return (r1.created_at ?? Date.distantPast) > (r2.created_at ?? Date.distantPast)
            }
        case .oldest:
            return reviews.sorted { ($0.created_at ?? Date.distantPast) < ($1.created_at ?? Date.distantPast) }
        case .highest:
            return reviews.sorted { $0.rating > $1.rating }
        case .lowest:
            return reviews.sorted { $0.rating < $1.rating }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Rating Summary
                    if stats.hasReviews {
                        RatingSummaryView(stats: stats)
                            .padding(.horizontal)
                    }

                    // Sort Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ReviewSortType.allCases) { type in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        sortType = type
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.iconName)
                                            .font(.caption2)
                                        Text(type.displayName)
                                            .font(.caption)
                                    }
                                    .fontWeight(.medium)
                                    .foregroundColor(sortType == type ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        sortType == type
                                            ? Color.blue
                                            : Color(UIColor.secondarySystemBackground)
                                    )
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // All Reviews
                    VStack(spacing: 12) {
                        ForEach(sortedReviews) { review in
                            ReviewCardView(
                                review: review,
                                currentUserId: currentUserId,
                                onEdit: onEdit,
                                onDelete: onDelete,
                                distinguishedUserIds: distinguishedUserIds
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle(L(.reviewsAndRatings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
