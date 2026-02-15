import SwiftUI

/// Vista de Términos y Condiciones / Aviso Legal
struct TerminosView: View {

    // MARK: - Environment
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.colorScheme) var colorScheme

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
                VStack(alignment: .leading, spacing: 24) {
                    // Cabecera
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text(L(.termsTitle))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Text(L(.termsLastUpdated))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    // Secciones legales
                    ForEach(sections, id: \.title) { section in
                        legalSection(title: section.title, body: section.body)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(L(.settingsTerms))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections
    private var sections: [(title: String, body: String)] {
        [
            (L(.termsSection1Title), L(.termsSection1Body)),
            (L(.termsSection2Title), L(.termsSection2Body)),
            (L(.termsSection3Title), L(.termsSection3Body)),
            (L(.termsSection4Title), L(.termsSection4Body)),
            (L(.termsSection5Title), L(.termsSection5Body)),
            (L(.termsSection6Title), L(.termsSection6Body)),
        ]
    }

    // MARK: - Section Component
    private func legalSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct TerminosView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TerminosView()
                .environmentObject(LocalizationManager.shared)
        }
    }
}
