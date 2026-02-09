import SwiftUI

/// Card moderna y visual para mostrar logros
struct AchievementCardView: View {
    let achievement: Logro
    let isUnlocked: Bool
    let currentProgress: Int
    let targetProgress: Int

    @State private var animateUnlock: Bool = false

    var progressPercentage: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon Side
            iconView

            // Content Side
            VStack(alignment: .leading, spacing: 8) {
                // Title & XP
                HStack {
                    Text(achievement.nombre)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isUnlocked ? .primary : .secondary)

                    Spacer()

                    XPBadge(xp: achievement.xp ?? 0, isUnlocked: isUnlocked)
                }

                // Description
                Text(achievement.descripcion ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Progress Bar
                if !isUnlocked {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(currentProgress) / \(targetProgress)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(Int(progressPercentage * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)

                                // Progress
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progressPercentage, height: 6)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progressPercentage)
                            }
                        }
                        .frame(height: 6)
                    }
                } else {
                    // Unlocked badge
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(L(.reviewCompleted))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(
            color: isUnlocked ? Color.green.opacity(0.2) : Color.black.opacity(0.06),
            radius: isUnlocked ? 8 : 4,
            x: 0,
            y: isUnlocked ? 4 : 2
        )
        .scaleEffect(animateUnlock ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateUnlock)
        .onAppear {
            if isUnlocked {
                animateUnlock = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateUnlock = false
                }
            }
        }
    }

    // MARK: - Icon View
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    isUnlocked
                        ? LinearGradient(
                            colors: [.green.opacity(0.2), .green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                )
                .frame(width: 56, height: 56)

            Image(systemName: achievementIcon)
                .font(.system(size: 24))
                .foregroundColor(isUnlocked ? .green : .gray)
        }
    }

    // MARK: - Card Background
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.secondarySystemBackground))
            .overlay(
                // Subtle gradient overlay for unlocked achievements
                Group {
                    if isUnlocked {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.05),
                                        Color.green.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
    }

    // MARK: - Achievement Icon Logic
    private var achievementIcon: String {
        guard let condition = achievement.condicion?.lowercased() else {
            return "star.fill"
        }

        if condition.contains("campo") || condition.contains("visit") {
            return "map.fill"
        } else if condition.contains("provincia") {
            return "building.2.fill"
        } else if condition.contains("día") || condition.contains("consecutiv") {
            return "calendar.badge.clock"
        } else if condition.contains("contribu") {
            return "photo.fill"
        } else {
            return "star.fill"
        }
    }
}

// MARK: - XP Badge
struct XPBadge: View {
    let xp: Int
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("+\(xp)")
                .fontWeight(.bold)
                .font(.caption)
        }
        .foregroundColor(isUnlocked ? .orange : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isUnlocked ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Preview
struct AchievementCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Unlocked achievement
            AchievementCardView(
                achievement: Logro(
                    id: UUID(),
                    nombre: "Explorador",
                    descripcion: "Visita tu primer campo de fútbol",
                    condicion: "visitar_1_campo",
                    orden: 1,
                    xp: 50
                ),
                isUnlocked: true,
                currentProgress: 1,
                targetProgress: 1
            )

            // In progress achievement
            AchievementCardView(
                achievement: Logro(
                    id: UUID(),
                    nombre: "Aficionado",
                    descripcion: "Visita 10 campos diferentes",
                    condicion: "visitar_10_campos",
                    orden: 2,
                    xp: 100
                ),
                isUnlocked: false,
                currentProgress: 5,
                targetProgress: 10
            )

            // Not started achievement
            AchievementCardView(
                achievement: Logro(
                    id: UUID(),
                    nombre: "Maestro Fotógrafo",
                    descripcion: "Contribuye con 25 fotos",
                    condicion: "contribuir_25_fotos",
                    orden: 3,
                    xp: 200
                ),
                isUnlocked: false,
                currentProgress: 0,
                targetProgress: 25
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
