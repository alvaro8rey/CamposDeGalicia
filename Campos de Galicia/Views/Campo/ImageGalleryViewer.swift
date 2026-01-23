import SwiftUI

/// Visor de galería de imágenes en pantalla completa
struct ImageGalleryViewer: View {
    let photos: [(url: String, userId: String)]
    let initialIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int

    init(photos: [(url: String, userId: String)], initialIndex: Int) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationView {
            TabView(selection: $currentIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    if let url = URL(string: photos[index].url) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.black)
                            case .failure:
                                VStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 40))
                                    Text("Error al cargar")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(Color.black)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("Foto \(currentIndex + 1) de \(photos.count)")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
            .navigationBarItems(trailing: Button("Cerrar") { dismiss() })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
