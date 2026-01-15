import SwiftUI

/// Vista de estadísticas del perfil (campos visitados, nivel, logros)
struct ProfileStatsView: View {

    // MARK: - Binding Properties
    @Binding var camposVisitados: Int
    @Binding var level: Int
    @Binding var totalAchievementsCount: Int

    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            Text("Tus Estadísticas")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                statCard(
                    icon: "map.fill",
                    value: "\(camposVisitados)",
                    label: "Campos\nVisitados",
                    color: .green
                )

                statCard(
                    icon: "star.fill",
                    value: "\(level)",
                    label: "Nivel\nActual",
                    color: .orange
                )

                statCard(
                    icon: "trophy.fill",
                    value: "\(totalAchievementsCount)",
                    label: "Logros\nDesbloqueados",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - Stat Card View
    @ViewBuilder
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct ProfileStatsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileStatsView(
            camposVisitados: .constant(15),
            level: .constant(3),
            totalAchievementsCount: .constant(8)
        )
        .padding()
    }
}
