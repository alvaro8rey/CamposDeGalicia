import SwiftUI
import Supabase
import PhotosUI

/// Vista modal para añadir o editar una reseña a un campo
struct AddReviewView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager

    let campoId: UUID
    let campoNombre: String
    let existingReview: Review? // Para editar
    let onReviewAdded: () -> Void

    @State private var rating: Int
    @State private var reviewText: String
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoPreviews: [Image] = []
    @State private var isAnonymous: Bool
    @State private var existingPhotoURLs: [String]

    private let maxCharacters = 500
    private let maxPhotos = 5

    init(campoId: UUID, campoNombre: String, existingReview: Review? = nil, onReviewAdded: @escaping () -> Void) {
        self.campoId = campoId
        self.campoNombre = campoNombre
        self.existingReview = existingReview
        self.onReviewAdded = onReviewAdded

        // Initialize states with existing review data if editing
        _rating = State(initialValue: existingReview?.rating ?? 0)
        _reviewText = State(initialValue: existingReview?.reseña ?? "")
        _isAnonymous = State(initialValue: existingReview?.is_anonymous ?? false)
        _existingPhotoURLs = State(initialValue: existingReview?.fotos ?? [])
    }

    var isEditMode: Bool {
        existingReview != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    // Campo info
                    Section {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue)
                            Text(campoNombre)
                                .font(.headline)
                        }
                    }

                    // Rating Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L(.reviewYourRating))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { index in
                                    Button {
                                        rating = index
                                    } label: {
                                        Image(systemName: index <= rating ? "star.fill" : "star")
                                            .font(.system(size: 32))
                                            .foregroundColor(index <= rating ? .orange : .gray.opacity(0.3))
                                            .scaleEffect(rating == index ? 1.2 : 1.0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)

                            if rating > 0 {
                                Text(ratingDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    } header: {
                        Label(L(.reviewRatingLabel), systemImage: "star.fill")
                    }

                    // Review Text Section
                    Section {
                        VStack(alignment: .trailing, spacing: 8) {
                            TextEditor(text: $reviewText)
                                .frame(minHeight: 120)
                                .overlay(alignment: .topLeading) {
                                    if reviewText.isEmpty {
                                        Text(L(.reviewPlaceholder))
                                            .foregroundColor(.secondary)
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                }

                            Text("\(reviewText.count)/\(maxCharacters)")
                                .font(.caption)
                                .foregroundColor(reviewText.count > maxCharacters ? .red : .secondary)
                        }
                    } header: {
                        Label(L(.reviewYourOpinion), systemImage: "text.bubble")
                    } footer: {
                        Text(L(.reviewGuidelines))
                            .font(.caption)
                    }

                    // Photos Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: maxPhotos - existingPhotoURLs.count,
                                selectionBehavior: .ordered,
                                matching: .images
                            ) {
                                Label(L(.reviewAddPhotosCount, existingPhotoURLs.count + selectedPhotos.count, maxPhotos), systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline)
                            }
                            .onChange(of: selectedPhotos) { oldSelection, newSelection in
                                Task {
                                    await loadPhotoPreviews(from: newSelection)
                                }
                            }

                            // Show existing photos + new photo previews
                            if !existingPhotoURLs.isEmpty || !photoPreviews.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // Existing photos from server
                                        ForEach(existingPhotoURLs.indices, id: \.self) { index in
                                            if let url = URL(string: existingPhotoURLs[index]) {
                                                ZStack(alignment: .topTrailing) {
                                                    CachedAsyncImage(url: url) { image in
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 80, height: 80)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    } placeholder: {
                                                        Color.gray.opacity(0.2)
                                                            .frame(width: 80, height: 80)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }

                                                    Button(action: {
                                                        existingPhotoURLs.remove(at: index)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .background(Color.red.opacity(0.8))
                                                            .clipShape(Circle())
                                                    }
                                                    .offset(x: 6, y: -6)
                                                }
                                            }
                                        }

                                        // New photo previews
                                        ForEach(photoPreviews.indices, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                photoPreviews[index]
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                                Button(action: {
                                                    removePhoto(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Color.red.opacity(0.8))
                                                        .clipShape(Circle())
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Label(L(.reviewPhotosOptional), systemImage: "photo")
                    } footer: {
                        Text(L(.reviewPhotosHelp, maxPhotos))
                            .font(.caption)
                    }

                    // Anonymous Section
                    Section {
                        Toggle(isOn: $isAnonymous) {
                            HStack {
                                Image(systemName: "eye.slash.fill")
                                    .foregroundColor(.blue)
                                Text(L(.reviewAnonymous))
                            }
                        }
                    } footer: {
                        Text(L(.reviewAnonymousHelp))
                            .font(.caption)
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle(isEditMode ? L(.reviewEdit) : L(.reviewAdd))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L(.cancel)) {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEditMode ? L(.save) : L(.reviewPublish)) {
                            Task { await submitReview() }
                        }
                        .disabled(!isValid || isSubmitting)
                        .fontWeight(.semibold)
                    }
                }
                .disabled(isSubmitting)
                .scrollDismissesKeyboard(.interactively)

                // Loading Overlay
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(isEditMode ? L(.reviewUpdating) : L(.reviewPublishing))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                }

                // Success Animation
                if showSuccess {
                    SuccessCheckmarkView(message: isEditMode ? L(.reviewUpdated) : L(.reviewPublished))
                }
            }
        }
    }

    // MARK: - Validation
    private var isValid: Bool {
        rating > 0 &&
        !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        reviewText.count <= maxCharacters
    }

    private var ratingDescription: String {
        switch rating {
        case 1: return L(.reviewRatingVeryBad)
        case 2: return L(.reviewRatingBad)
        case 3: return L(.reviewRatingRegular)
        case 4: return L(.reviewRatingGood)
        case 5: return L(.reviewRatingExcellent)
        default: return ""
        }
    }

    // MARK: - Photo Methods
    private func loadPhotoPreviews(from items: [PhotosPickerItem]) async {
        photoPreviews.removeAll()
        errorMessage = nil

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Validar tamaño de la imagen
                    do {
                        try InputValidator.validateImageSize(data, maxSizeInMB: 5.0)
                    } catch {
                        errorMessage = error.localizedDescription
                        ToastManager.shared.error(error.localizedDescription)
                        continue
                    }

                    if let uiImage = UIImage(data: data) {
                        let image = Image(uiImage: uiImage)
                        photoPreviews.append(image)
                    }
                }
            } catch {
                ErrorHandler.shared.handle(error, showToUser: false, context: "load_photo_preview_review")
            }
        }
    }

    private func removePhoto(at index: Int) {
        selectedPhotos.remove(at: index)
        photoPreviews.remove(at: index)
    }

    private func uploadPhotos() async throws -> [String]? {
        guard !selectedPhotos.isEmpty else { return nil }

        var uploadedURLs: [String] = []
        for (index, photoItem) in selectedPhotos.enumerated() {
            do {
                guard let data = try await photoItem.loadTransferable(type: Data.self) else {
                    Logger.warning("No se pudo cargar foto #\(index)")
                    continue
                }

                // Validar tamaño de imagen antes de subir
                try InputValidator.validateImageSize(data, maxSizeInMB: 5.0)

                let fileName = "\(campoId.uuidString)-review-\(UUID().uuidString)-\(index).jpg"

                _ = try await supabase.storage
                    .from("fotos-campos")
                    .upload(fileName, data: data)

                let publicURL = try supabase.storage
                    .from("fotos-campos")
                    .getPublicURL(path: fileName)
                    .absoluteString

                uploadedURLs.append(publicURL)
            } catch {
                Logger.error("Error uploading photo \(index): \(error.localizedDescription)")
                ErrorHandler.shared.handle(error, showToUser: false, context: "upload_review_photo_\(index)")
                throw AppError.storageUploadFailed
            }
        }

        return uploadedURLs.isEmpty ? nil : uploadedURLs
    }

    // MARK: - Submit Review
    private func submitReview() async {
        errorMessage = nil
        isSubmitting = true

        defer { isSubmitting = false }

        guard let userId = authViewModel.user?.id else {
            ErrorHandler.shared.handle(.notAuthenticated, context: "submit_review")
            errorMessage = "\(L(.error)): \(L(.errorUserNotAuthenticated))"
            return
        }

        // Validar inputs
        do {
            // Validar rating
            try InputValidator.validateInteger(String(rating), min: 1, max: 5)

            // Validar texto de la reseña
            let trimmedText = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
            try InputValidator.validateTextLength(trimmedText, min: 1, max: maxCharacters, fieldName: "reseña")
        } catch {
            if let validationError = error as? ValidationError {
                errorMessage = validationError.errorDescription
                ToastManager.shared.error(validationError.errorDescription ?? "Error de validación")
            }
            return
        }

        do {
            // Upload new photos
            let newPhotoURLs = try await uploadPhotos()

            // Combine existing and new photo URLs
            var allPhotoURLs = existingPhotoURLs
            if let newURLs = newPhotoURLs {
                allPhotoURLs.append(contentsOf: newURLs)
            }
            let finalPhotoURLs: [String]? = allPhotoURLs.isEmpty ? nil : allPhotoURLs

            if let reviewId = existingReview?.id {
                // UPDATE existing review
                let reviewsManager = ReviewsManager()
                let success = await reviewsManager.updateReview(
                    reviewId,
                    userId: userId,
                    text: reviewText.trimmingCharacters(in: .whitespacesAndNewlines),
                    rating: rating,
                    fotos: finalPhotoURLs,
                    isAnonymous: isAnonymous
                )

                if !success {
                    errorMessage = "Error al actualizar la reseña"
                    return
                }

                Logger.success("✅ Reseña actualizada correctamente")
            } else {
                // CREATE new review
                let reviewerName = "\(authViewModel.nombre) \(authViewModel.apellidos)".trimmingCharacters(in: .whitespaces)

                let reviewCreate = ReviewCreate(
                    campo_id: campoId.uuidString,
                    user_id: userId.uuidString,
                    reseña: reviewText.trimmingCharacters(in: .whitespacesAndNewlines),
                    rating: rating,
                    reviewer_name: reviewerName.isEmpty ? "Usuario" : reviewerName,
                    reviewer_avatar_url: authViewModel.avatarURL,
                    fotos: finalPhotoURLs,
                    is_anonymous: isAnonymous
                )

                _ = try await supabase.from("reseñas")
                    .insert(reviewCreate)
                    .execute()

                Logger.success("✅ Reseña publicada correctamente")

                // Actualizar nivel y XP del usuario después de publicar la reseña
                do {
                    try await LevelManager.shared.updateLevelAndXP(for: userId.uuidString)
                    Logger.success("✅ XP actualizado correctamente")

                    // Toast de éxito
                    await MainActor.run {
                        let baseXP = 25
                        var bonusXP = 0
                        if reviewText.count > 100 { bonusXP += 10 }
                        if !allPhotoURLs.isEmpty { bonusXP += 15 }
                        let totalXP = baseXP + bonusXP

                        ToastManager.shared.xpGained(totalXP, reason: isEditMode ? "Reseña actualizada" : "Reseña publicada")
                    }
                } catch {
                    Logger.error("⚠️ Error al actualizar XP: \(error.localizedDescription)")
                    // No lanzamos el error para no bloquear la UI, la reseña ya está publicada
                }
            }

            // Show success animation
            withAnimation {
                showSuccess = true
            }

            // Wait and dismiss
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            onReviewAdded()
            dismiss()

        } catch {
            let appError = convertToAppError(error, context: isEditMode ? "update_review" : "create_review")
            await MainActor.run {
                ErrorHandler.shared.handle(appError, context: isEditMode ? "update_review" : "create_review")
                errorMessage = appError.errorDescription
            }
        }
    }

    /// Convierte errores de reseña en AppError apropiados
    private func convertToAppError(_ error: Error, context: String) -> AppError {
        let errorDesc = error.localizedDescription.lowercased()

        if errorDesc.contains("network") || errorDesc.contains("timeout") {
            return .networkError(error)
        } else if errorDesc.contains("upload") || errorDesc.contains("storage") {
            return .storageUploadFailed
        } else if errorDesc.contains("unauthorized") || errorDesc.contains("invalid token") {
            return .sessionExpired
        } else if errorDesc.contains("duplicate") {
            return .duplicateRecord
        }

        return .unknown(error)
    }
}

/// Animación de checkmark de éxito
struct SuccessCheckmarkView: View {
    let message: String
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

