import SwiftUI

/// Card moderna para mostrar recompensa diaria con días consecutivos
struct DailyRewardCardView: View {
    let currentDay: Int
    let dailyXP: Int
    let hasClaimedToday: Bool
    let isProcessing: Bool
    let onClaim: () -> Void
    let onTestNotification: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            headerSection

            // Days Progress
            daysProgressView

            // Action Button
            actionButton

            // Test button (opcional, puedes quitarlo en producción)
            #if DEBUG
            testButton
            #endif
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
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
            VStack(spacing: 2) {
                Text("\(currentDay)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.orange)

                Text(L(.dailyRewardStreak))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }

    // MARK: - Days Progress
    private var daysProgressView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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
                HStack(spacing: 8) {
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
                .padding(.vertical, 16)
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
                .cornerRadius(14)
                .shadow(color: isProcessing ? .clear : Color.orange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .disabled(isProcessing)
            .scaleEffect(isProcessing ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: isProcessing)
        } else if hasClaimedToday {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(L(.dailyRewardClaimedToday))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.green.opacity(0.1)
            )
            .cornerRadius(14)
        }
    }

    // MARK: - Test Button (Debug)
    #if DEBUG
    private var testButton: some View {
        Button(action: onTestNotification) {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge")
                    .font(.caption)
                Text(L(.dailyRewardTestNotif))
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    #endif

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
        switch day {
        case 1: return 10
        case 2: return 20
        case 3: return 30
        case 4: return 50
        case 5: return 75
        case 6: return 100
        default: return 150
        }
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
                onClaim: {},
                onTestNotification: {}
            )

            // Already claimed
            DailyRewardCardView(
                currentDay: 5,
                dailyXP: 75,
                hasClaimedToday: true,
                isProcessing: false,
                onClaim: {},
                onTestNotification: {}
            )

            // Processing
            DailyRewardCardView(
                currentDay: 2,
                dailyXP: 20,
                hasClaimedToday: false,
                isProcessing: true,
                onClaim: {},
                onTestNotification: {}
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
