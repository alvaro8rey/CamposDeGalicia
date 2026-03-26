import SwiftUI

/// Card moderna para mostrar recompensa diaria con días consecutivos
struct DailyRewardCardView: View {
    let currentDay: Int
    let dailyXP: Int
    let hasClaimedToday: Bool
    let isProcessing: Bool
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg + 2) {
            // Header
            headerSection

            // Days Progress
            daysProgressView

            // Action Button
            actionButton
        }
        .padding(Spacing.xl)
        .background(cardBackground)
        .cornerRadius(CornerRadius.xl)
        .shadowLarge()
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundColor(.orange)

                    Text(L(.dailyRewardTitle))
                        .font(.system(size: 22, weight: .bold))
                }

                Text(hasClaimedToday ? L(.dailyRewardClaimed) : L(.dailyRewardClaim, dailyXP))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Streak Counter
            VStack(spacing: Spacing.xs - 2) {
                Text("\(currentDay)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.orange)

                Text(L(.dailyRewardStreak))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(Opacity.light))
            )
        }
    }

    // MARK: - Days Progress
    private var daysProgressView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(1...7, id: \.self) { day in
                    DayCircleView(
                        day: day,
                        currentDay: currentDay,
                        xpValue: dailyXPValue(for: day),
                        isCurrent: day == currentDay,
                        isCompleted: day < currentDay,
                        isNext: day == currentDay + 1
                    )
                }
            }
        }
    }

    // MARK: - Action Button
    @ViewBuilder
    private var actionButton: some View {
        if dailyXP > 0 && !hasClaimedToday {
            Button(action: {
                HapticFeedback.medium()
                onClaim()
            }) {
                HStack(spacing: Spacing.sm) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.body)
                    }

                    Text(isProcessing ? "Procesando..." : "Reclamar +\(dailyXP) XP")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(
                    isProcessing ?
                        AnyView(Color.gray) :
                        AnyView(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .cornerRadius(CornerRadius.md + 2)
                .shadow(color: isProcessing ? .clear : Color.orange.opacity(Opacity.semitransparent), radius: 8, x: 0, y: 4)
            }
            .disabled(isProcessing)
            .scaleEffect(isProcessing ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: isProcessing)
        } else if hasClaimedToday {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(L(.dailyRewardClaimedToday))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md + 2)
            .background(
                Color.green.opacity(Opacity.light)
            )
            .cornerRadius(CornerRadius.md + 2)
        }
    }

    // MARK: - Card Background
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(UIColor.secondarySystemBackground))
            .overlay(
                // Subtle animated gradient
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.03),
                        Color.pink.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Helpers
    private func dailyXPValue(for day: Int) -> Int {
        ProgressUtils.dailyXP(for: day)
    }
}

// MARK: - Day Circle View
struct DayCircleView: View {
    let day: Int
    let currentDay: Int
    let xpValue: Int
    let isCurrent: Bool
    let isCompleted: Bool
    let isNext: Bool

    @State private var animateGlow: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Text(L(.dailyRewardDay, day))
                .font(.caption)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundColor(isCurrent ? .orange : .secondary)

            ZStack {
                // Background Circle
                Circle()
                    .fill(circleBackgroundColor)
                    .frame(width: 56, height: 56)

                // Glow effect for current day
                if isCurrent {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 56, height: 56)
                        .opacity(animateGlow ? 0.3 : 0.1)
                        .scaleEffect(animateGlow ? 1.2 : 1.0)
                        .animation(
                            Animation
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: animateGlow
                        )
                }

                // Icon/Checkmark
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else if isCurrent {
                    Image(systemName: "gift.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            Text("+\(xpValue) XP")
                .font(.caption2)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundColor(isCurrent ? .orange : .secondary)
        }
        .frame(width: 64)
        .onAppear {
            if isCurrent {
                animateGlow = true
            }
        }
    }

    private var circleBackgroundColor: Color {
        if isCompleted {
            return Color.green
        } else if isCurrent {
            return Color.orange.opacity(0.2)
        } else {
            return Color(UIColor.tertiarySystemBackground)
        }
    }
}

// MARK: - Preview
struct DailyRewardCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Not claimed
            DailyRewardCardView(
                currentDay: 3,
                dailyXP: 30,
                hasClaimedToday: false,
                isProcessing: false,
                onClaim: {}
            )

            // Already claimed
            DailyRewardCardView(
                currentDay: 5,
                dailyXP: 75,
                hasClaimedToday: true,
                isProcessing: false,
                onClaim: {}
            )

            // Processing
            DailyRewardCardView(
                currentDay: 2,
                dailyXP: 20,
                hasClaimedToday: false,
                isProcessing: true,
                onClaim: {}
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
