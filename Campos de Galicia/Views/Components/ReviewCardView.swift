import SwiftUI

/// Card moderna para mostrar reseñas de campos
struct ReviewCardView: View {
    let review: Review
    let currentUserId: UUID?
    let onEdit: ((Review) -> Void)?
    let onDelete: ((Review) -> Void)?
    var distinguishedUserIds: Set<UUID> = []

    @State private var selectedPhotoIndex: Int = 0
    @State private var showingImageViewer: Bool = false
    @State private var showingDetail: Bool = false

    var isOwnReview: Bool {
        guard let userId = currentUserId else { return false }
        return review.user_id == userId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar + Name + Rating
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                UserAvatarView(
                    avatarURL: review.reviewer_avatar_url,
                    userName: review.displayName,
                    size: 40,
                    showBadge: distinguishedUserIds.contains(review.user_id)
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(review.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        // Star Rating
                        StarRatingView(rating: review.rating, size: 13, color: .orange)
                    }

                    Text(review.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Edit button for own reviews
                if isOwnReview, let onEdit = onEdit {
                    Button(action: {
                        onEdit(review)
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Review Text
            Text(review.reseña)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Edited indicator (like Google Reviews)
            if review.isEdited, let updatedDate = review.updated_at {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.caption2)
                    Text(L(.reviewEditedAt, formatEditDate(updatedDate)))
                        .font(.caption)
                }
                .foregroundColor(.secondary.opacity(0.8))
            }

            // Photos (if any)
            if let fotos = review.fotos, !fotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(fotos.indices, id: \.self) { index in
                            if let url = URL(string: fotos[index]) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } placeholder: {
                                    ZStack {
                                        Color.gray.opacity(0.2)
                                        ProgressView()
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .onTapGesture {
                                    selectedPhotoIndex = index
                                    showingImageViewer = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        .contextMenu {
            if isOwnReview {
                if let onEdit = onEdit {
                    Button {
                        onEdit(review)
                    } label: {
                        Label(L(.reviewEditAction), systemImage: "pencil")
                    }
                }

                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete(review)
                    } label: {
                        Label(L(.reviewDeleteAction), systemImage: "trash")
                    }
                }
            }
        }
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingImageViewer) {
            if let fotos = review.fotos, !fotos.isEmpty {
                ReviewImageViewer(photos: fotos, initialIndex: selectedPhotoIndex)
            }
        }
        .sheet(isPresented: $showingDetail) {
            ReviewDetailView(
                review: review,
                showBadge: distinguishedUserIds.contains(review.user_id)
            )
        }
    }

    // MARK: - Formatting
    private func formatEditDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Vista de detalle para una reseña (se abre al pulsar)
struct ReviewDetailView: View {
    let review: Review
    var showBadge: Bool = false
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingImageViewer: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header: Avatar + Name
                    HStack(spacing: 14) {
                        UserAvatarView(
                            avatarURL: review.reviewer_avatar_url,
                            userName: review.displayName,
                            size: 56,
                            showBadge: showBadge
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(review.displayName)
                                .font(.system(size: 18, weight: .semibold))

                            Text(review.formattedDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    // Star Rating (large)
                    StarRatingView(rating: review.rating, size: 22, color: .orange)

                    // Full Review Text
                    Text(review.reseña)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    // Edited indicator
                    if review.isEdited, let updatedDate = review.updated_at {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            let fmt = RelativeDateTimeFormatter()
                            Text(L(.reviewEditedAt, fmt.localizedString(for: updatedDate, relativeTo: Date())))
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Photos (full size grid)
                    if let fotos = review.fotos, !fotos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(fotos.indices, id: \.self) { index in
                                    if let url = URL(string: fotos[index]) {
                                        CachedAsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 160)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        } placeholder: {
                                            ZStack {
                                                Color.gray.opacity(0.2)
                                                ProgressView()
                                            }
                                            .frame(height: 160)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .onTapGesture {
                                            selectedPhotoIndex = index
                                            showingImageViewer = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .navigationTitle(L(.reviewDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingImageViewer) {
                if let fotos = review.fotos, !fotos.isEmpty {
                    ReviewImageViewer(photos: fotos, initialIndex: selectedPhotoIndex)
                }
            }
        }
    }
}

/// Visor de imágenes para reseñas
struct ReviewImageViewer: View {
    let photos: [String]
    let initialIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int

    init(photos: [String], initialIndex: Int) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(photos.indices, id: \.self) { index in
                        if let url = URL(string: photos[index]) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    VStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                        Text(L(.reviewLoadError))
                                            .foregroundColor(.gray)
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    Spacer()
                    Text("\(currentIndex + 1) de \(photos.count)")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.bottom, 30)
                }
            }
        }
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

                        Text("\(stats.totalReviews) \(stats.totalReviews == 1 ? L(.reviewSingle) : L(.reviewPlural))")
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

            Text(L(.reviewNoReviewsYet))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L(.reviewBeFirst))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

/// Card compacta estilo App Store para slider horizontal
struct CompactReviewCardView: View {
    let review: Review
    var distinguishedUserIds: Set<UUID> = []
    @State private var isExpanded: Bool = false
    @State private var showingDetail: Bool = false

    private let maxPreviewLength = 150

    var truncatedText: String {
        if review.reseña.count > maxPreviewLength && !isExpanded {
            return String(review.reseña.prefix(maxPreviewLength)) + "..."
        }
        return review.reseña
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top, spacing: 10) {
                // Star Rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= review.rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(index <= review.rating ? .orange : Color.gray.opacity(0.3))
                    }
                }

                Spacer()

                // Date
                Text(review.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Review text
            Text(truncatedText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(2)
                .lineLimit(isExpanded ? nil : 4)
                .onTapGesture {
                    if review.reseña.count > maxPreviewLength {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                }

            // More button if text is long
            if review.reseña.count > maxPreviewLength {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? L(.reviewShowLess) : L(.reviewShowMore))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }

            // Photos preview (small)
            if let fotos = review.fotos, !fotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(fotos.prefix(3).indices, id: \.self) { index in
                            if let url = URL(string: fotos[index]) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }

                        if fotos.count > 3 {
                            ZStack {
                                Color.gray.opacity(0.2)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Text("+\(fotos.count - 3)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Divider()

            // User info
            HStack(spacing: 8) {
                UserAvatarView(
                    avatarURL: review.reviewer_avatar_url,
                    userName: review.displayName,
                    size: 24,
                    showBadge: distinguishedUserIds.contains(review.user_id)
                )

                Text(review.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if review.isEdited {
                    Text("· \(L(.reviewEdited))")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            ReviewDetailView(
                review: review,
                showBadge: distinguishedUserIds.contains(review.user_id)
            )
        }
    }
}

