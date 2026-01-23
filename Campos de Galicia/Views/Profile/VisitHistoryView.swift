import SwiftUI

/// Vista del historial de visitas a campos
struct VisitHistoryView: View {

    // MARK: - Properties
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var profileVM: ProfileViewModel
    var onShowDetails: () -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Últimas Visitas")
                .font(.title3)
                .fontWeight(.bold)

            if profileVM.isLoadingHistorial {
                LoadingView(message: "Cargando visitas...", style: .spinner)
                    .frame(height: 100)
            } else if profileVM.historialCampos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Aún no has visitado ningún campo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(profileVM.historialCampos.prefix(3), id: \.id) { campo in
                        HistoryCardView(campo: campo)
                    }

                    if profileVM.allVisits.count > 3 {
                        Button(action: onShowDetails) {
                            HStack {
                                Text("Ver todas (\(profileVM.allVisits.count))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - History Card View
struct HistoryCardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let campo: CampoModel
    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    var body: some View {
        NavigationLink(destination: CampoDetalleView(campoID: campo.id)
            .environmentObject(authViewModel)) {
            HStack(spacing: 12) {
                // Image
                let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                if let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                            .clipped()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(campo.nombre)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("\(campo.localidad), \(campo.provincia)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Visit Detail View (Full History Sheet)
struct VisitDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let allVisits: [(campo: CampoModel, date: Date)]
    let formatDate: (Date) -> String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Historial de Visitas")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { withAnimation { dismiss() } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()

                // List
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(allVisits, id: \.campo.id) { visit in
                            NavigationLink(destination: CampoDetalleView(campoID: visit.campo.id)
                                .environmentObject(authViewModel)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        let imageURL = (visit.campo.foto_url?.isEmpty == false ? visit.campo.foto_url : nil) ?? "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

                                        if let url = URL(string: imageURL) {
                                            CachedAsyncImage(url: url) { image in
                                                image.resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).clipped()
                                            } placeholder: {
                                                Color.gray.opacity(0.3).frame(width: 60, height: 60).cornerRadius(10)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(visit.campo.nombre)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("\(visit.campo.localidad), \(visit.campo.provincia)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(formatDate(visit.date))
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Preview
struct VisitHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ProfileViewModel()
        VisitHistoryView(profileVM: vm, onShowDetails: {})
            .padding()
    }
}
