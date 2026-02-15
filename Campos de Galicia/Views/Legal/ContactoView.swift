import SwiftUI

/// Vista de Contacto
struct ContactoView: View {

    // MARK: - Environment
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.colorScheme) var colorScheme

    private let contactEmail = "info@camposdegalicia.es"

    // MARK: - Body
    var body: some View {
        ZStack {
            // Fondo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Icono cabecera
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(L(.contactTitle))
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(L(.contactSubtitle))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 16)

                    // Tarjeta de email
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L(.contactEmailLabel))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(contactEmail)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()
                        }
                        .padding()

                        Divider()
                            .padding(.leading, 56)

                        Button(action: openMail) {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .font(.subheadline)
                                Text(L(.contactEmailAction))
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.blue)
                        }
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Hint sugerencias
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        Text(L(.contactSuggestHint))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(L(.settingsContact))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions
    private func openMail() {
        let urlString = "mailto:\(contactEmail)?subject=Campos%20de%20Galicia"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview
struct ContactoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContactoView()
                .environmentObject(LocalizationManager.shared)
        }
    }
}
