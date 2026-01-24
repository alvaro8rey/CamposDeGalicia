import SwiftUI
import PhotosUI
import Supabase

/// Vista del formulario de contribución para un campo
struct ContribucionFormView: View {
    let campo: CampoModel
    let onSubmit: (CampoContribucion) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoPreviews: [Image] = []
    @State private var tieneCantina: Bool = false
    @State private var aforoGrada: String = ""
    @State private var medidasCampo: String = ""
    @State private var tipoIluminacion: String = ""
    @State private var estadoCesped: String = ""
    @State private var accesibilidad: String = ""
    @State private var notas: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información adicional para \(campo.nombre)")) {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        selectionBehavior: .ordered,
                        matching: .images
                    ) {
                        Label("Añadir fotos", systemImage: "photo.on.rectangle.angled")
                            .foregroundColor(.blue)
                    }
                    .onChange(of: selectedPhotos) { oldSelection, newSelection in
                        Task {
                            await loadPhotoPreviews(from: newSelection)
                        }
                    }

                    if !photoPreviews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(photoPreviews.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        photoPreviews[index]
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                            .padding(.vertical, 4)

                                        Button(action: {
                                            removePhoto(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 5, y: -5)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Toggle("¿Tiene cantina?", isOn: $tieneCantina)

                    TextField("Aforo de la grada (número)", text: $aforoGrada)
                        .keyboardType(.numberPad)

                    TextField("Medidas del campo (ej. 105x68 metros)", text: $medidasCampo)

                    Picker("Tipo de iluminación", selection: $tipoIluminacion) {
                        Text("Seleccionar").tag("")
                        Text("Natural").tag("Natural")
                        Text("Artificial").tag("Artificial")
                    }

                    Picker("Estado del césped", selection: $estadoCesped) {
                        Text("Seleccionar").tag("")
                        Text("Bueno").tag("Bueno")
                        Text("Regular").tag("Regular")
                        Text("Malo").tag("Malo")
                    }

                    Picker("Accesibilidad", selection: $accesibilidad) {
                        Text("Seleccionar").tag("")
                        Text("Sí, tiene acceso para discapacitados").tag("Sí, tiene acceso para discapacitados")
                        Text("No, no tiene acceso").tag("No, no tiene acceso")
                    }

                    TextEditor(text: $notas)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Aportar información")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        Task { await submitForm() }
                    }
                    .disabled(!isFormValid())
                }
            }
        }
    }

    private func isFormValid() -> Bool {
        !selectedPhotos.isEmpty ||
        tieneCantina ||
        !aforoGrada.isEmpty ||
        !medidasCampo.isEmpty ||
        !tipoIluminacion.isEmpty ||
        !estadoCesped.isEmpty ||
        !accesibilidad.isEmpty ||
        !notas.isEmpty
    }

    private func loadPhotoPreviews(from items: [PhotosPickerItem]) async {
        photoPreviews.removeAll()
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    photoPreviews.append(Image(uiImage: uiImage))
                }
            } catch {
                print("Error loading photo preview:", error)
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

        for (index, item) in selectedPhotos.enumerated() {
            guard let data = try await item.loadTransferable(type: Data.self) else { continue }

            let fileName = "\(campo.id.uuidString)-\(UUID().uuidString)-photo-\(index).jpg"

            _ = try await supabase.storage.from("fotos-campos").upload(fileName, data: data)

            let publicURL = try supabase.storage.from("fotos-campos").getPublicURL(path: fileName).absoluteString
            uploadedURLs.append(publicURL)
        }

        return uploadedURLs.isEmpty ? nil : uploadedURLs
    }

    private func submitForm() async {
        guard let currentUser = supabase.auth.currentUser else { return }

        do {
            let fotosURLs = try await uploadPhotos()

            let contribucion = CampoContribucion(
                id_usuario: currentUser.id.uuidString,
                id_campo: campo.id.uuidString,
                fotos_adicionales: fotosURLs,
                tiene_cantina: tieneCantina ? true : nil,
                aforo_grada: Int(aforoGrada),
                medidas_campo: medidasCampo.isEmpty ? nil : medidasCampo,
                tipo_iluminacion: tipoIluminacion.isEmpty ? nil : tipoIluminacion,
                estado_cesped: estadoCesped.isEmpty ? nil : estadoCesped,
                accesibilidad: accesibilidad.isEmpty ? nil : accesibilidad,
                notas: notas.isEmpty ? nil : notas,
                fecha: Date(),
                aprobada: false
            )

            onSubmit(contribucion)
            dismiss()
        } catch {
            print("Error submitting contribution:", error)
        }
    }
}
