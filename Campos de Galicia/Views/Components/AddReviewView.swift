import SwiftUI
import Supabase
import PhotosUI

/// Vista modal para añadir una reseña a un campo
struct AddReviewView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    let campoId: UUID
    let campoNombre: String
    let onReviewAdded: () -> Void

    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoPreviews: [Image] = []

    private let maxCharacters = 500
    private let maxPhotos = 5

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
                            Text("Tu valoración")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { index in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            rating = index
                                        }
                                    } label: {
                                        Image(systemName: index <= rating ? "star.fill" : "star")
                                            .font(.system(size: 32))
                                            .foregroundColor(index <= rating ? .orange : .gray.opacity(0.3))
                                    }
                                    .scaleEffect(rating == index ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                            if rating > 0 {
                                Text(ratingDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    } header: {
                        Label("Valoración", systemImage: "star.fill")
                    }

                    // Review Text Section
                    Section {
                        VStack(alignment: .trailing, spacing: 8) {
                            TextEditor(text: $reviewText)
                                .frame(minHeight: 120)
                                .overlay(alignment: .topLeading) {
                                    if reviewText.isEmpty {
                                        Text("Cuéntanos tu experiencia en este campo...")
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
                        Label("Tu opinión", systemImage: "text.bubble")
                    } footer: {
                        Text("Sé respetuoso y describe tu experiencia de forma honesta.")
                            .font(.caption)
                    }

                    // Photos Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: maxPhotos,
                                selectionBehavior: .ordered,
                                matching: .images
                            ) {
                                Label("Añadir fotos (\(selectedPhotos.count)/\(maxPhotos))", systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline)
                            }
                            .onChange(of: selectedPhotos) { newSelection in
                                Task {
                                    await loadPhotoPreviews(from: newSelection)
                                }
                            }

                            if !photoPreviews.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
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
                        Label("Fotos (opcional)", systemImage: "photo")
                    } footer: {
                        Text("Añade hasta \(maxPhotos) fotos para compartir tu experiencia.")
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
                .navigationTitle("Nueva Reseña")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Publicar") {
                            Task { await submitReview() }
                        }
                        .disabled(!isValid || isSubmitting)
                        .fontWeight(.semibold)
                    }
                }
                .disabled(isSubmitting)

                // Loading Overlay
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Publicando reseña...")
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                }

                // Success Animation
                if showSuccess {
                    SuccessCheckmarkView()
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
        case 1: return "😞 Muy malo"
        case 2: return "😕 Malo"
        case 3: return "😐 Regular"
        case 4: return "😊 Bueno"
        case 5: return "🤩 Excelente"
        default: return ""
        }
    }

    // MARK: - Photo Methods
    private func loadPhotoPreviews(from items: [PhotosPickerItem]) async {
        photoPreviews.removeAll()
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let image = Image(uiImage: uiImage)
                    photoPreviews.append(image)
                }
            } catch {
                Logger.error("Error al cargar previsualización: \(error.localizedDescription)")
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
            guard let data = try await photoItem.loadTransferable(type: Data.self) else {
                Logger.warning("No se pudo cargar foto #\(index)")
                continue
            }

            let fileName = "\(campoId.uuidString)-review-\(UUID().uuidString)-\(index).jpg"

            _ = try await supabase.storage
                .from("fotos-campos")
                .upload(path: fileName, file: data)

            let publicURL = try supabase.storage
                .from("fotos-campos")
                .getPublicURL(path: fileName)
                .absoluteString

            uploadedURLs.append(publicURL)
        }

        return uploadedURLs.isEmpty ? nil : uploadedURLs
    }

    // MARK: - Submit Review
    private func submitReview() async {
        errorMessage = nil
        isSubmitting = true

        defer { isSubmitting = false }

        guard let userId = authViewModel.user?.id else {
            errorMessage = "Error: Usuario no autenticado"
            return
        }

        let reviewerName = "\(authViewModel.nombre) \(authViewModel.apellidos)".trimmingCharacters(in: .whitespaces)

        do {
            // Upload photos first
            let photoURLs = try await uploadPhotos()

            let reviewCreate = ReviewCreate(
                campo_id: campoId.uuidString,
                user_id: userId.uuidString,
                reseña: reviewText.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: rating,
                reviewer_name: reviewerName.isEmpty ? "Usuario" : reviewerName,
                fotos: photoURLs
            )

            _ = try await supabase.from("reseñas")
                .insert(reviewCreate)
                .execute()

            Logger.success("✅ Reseña publicada correctamente")

            // Show success animation
            withAnimation {
                showSuccess = true
            }

            // Wait and dismiss
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            onReviewAdded()
            dismiss()

        } catch {
            errorMessage = "Error al publicar la reseña: \(error.localizedDescription)"
            Logger.error("Error publicando reseña: \(error.localizedDescription)")
        }
    }
}

/// Animación de checkmark de éxito
struct SuccessCheckmarkView: View {
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

                Text("¡Reseña publicada!")
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

