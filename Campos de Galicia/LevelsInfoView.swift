import SwiftUI
import Supabase

struct LevelsInfoView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var level: Int = 1
    @State private var currentXP: Int = 0
    @State private var xpToNextLevel: Int = 100
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var lastUpdatedFromNotification: Date? = nil
    @State private var expandedCardId: String? = nil // Control de acordeón
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                titleSection
                progressSection
                explanationSection
                xpMethodsSection
                benefitsSection
                errorSection
                Spacer(minLength: 30)
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(L(.levelsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await loadUserData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateXP)) { notification in
            if let userInfo = notification.userInfo,
               let newXP = userInfo["xp"] as? Int,
               let newLevel = userInfo["level"] as? Int,
               let newXPToNextLevel = userInfo["xpToNextLevel"] as? Int {
                level = newLevel
                currentXP = newXP
                xpToNextLevel = newXPToNextLevel
                lastUpdatedFromNotification = Date()
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
                .font(.title2)
            Text(L(.levelsInfoTitle))
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(gradient: Gradient(colors: [.blue, .purple]),
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                Text("\(level)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var progressSection: some View {
        // Cálculo "in-level"
        let base = LevelCurve.xpNeededToReachLevel(level)
        let span = max(LevelCurve.xpSpanForLevel(level), 1)
        let gainedInLevel = max(0, currentXP - base)
        let progress = min(max(Double(gainedInLevel) / Double(span), 0), 1)

        return VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .frame(height: 24)

                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorScheme == .dark ? Color.blue.opacity(0.6) : Color.green,
                                    colorScheme == .dark ? Color.green.opacity(0.6) : Color.blue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress), alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), lineWidth: 1)
                        )
                }
            }

            VStack(spacing: 2) {
                HStack {
                    Text(L(.profileLevel, level))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(gainedInLevel) / \(span) XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Spacer()
                    Text(L(.levelsTotal, currentXP))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(L(.levelsWhatFor))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 10) {
                BenefitRow(icon: "star.fill", color: .yellow, text: L(.levelsBenefitVisibility))
                BenefitRow(icon: "medal.fill", color: .orange, text: L(.levelsBenefitRecognition))
                BenefitRow(icon: "chart.line.uptrend.xyaxis", color: .green, text: L(.levelsBenefitProgress))
                BenefitRow(icon: "trophy.fill", color: .purple, text: L(.levelsBenefitUnlock))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.blue.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var xpMethodsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.green)
                    .font(.title3)
                Text(L(.levelsHowToGetXP))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            VStack(spacing: 10) {
                XPMethodCard(
                    id: "visitar",
                    icon: "map.fill",
                    title: L(.levelsVisitFields),
                    description: L(.levelsVisitFieldsDesc),
                    xpRange: L(.levelsVariable),
                    expandedCardId: $expandedCardId
                )

                XPMethodCard(
                    id: "reseñas",
                    icon: "text.bubble.fill",
                    title: L(.levelsWriteReviews),
                    description: L(.levelsWriteReviewsDesc),
                    xpRange: "25-55 XP",
                    details: [
                        L(.levelsReviewBase),
                        L(.levelsReviewDetailed),
                        L(.levelsReviewPhotos),
                        L(.levelsReviewEdited)
                    ],
                    expandedCardId: $expandedCardId
                )

                XPMethodCard(
                    id: "diaria",
                    icon: "calendar.badge.clock",
                    title: L(.levelsDailyReward),
                    description: L(.levelsDailyRewardDesc),
                    xpRange: "20-70 XP",
                    details: [
                        L(.levelsDailyDay, 1, 20),
                        L(.levelsDailyDay, 2, 30),
                        L(.levelsDailyDay, 3, 40),
                        L(.levelsDailyDay, 4, 50),
                        "Día 5-6: 70 XP"
                    ],
                    expandedCardId: $expandedCardId
                )

                XPMethodCard(
                    id: "logros",
                    icon: "trophy.fill",
                    title: L(.levelsUnlockAchievements),
                    description: L(.levelsUnlockAchievementsDesc),
                    xpRange: "50-1000 XP",
                    details: [
                        L(.levelsAchievementFields),
                        L(.levelsAchievementStreaks),
                        L(.levelsAchievementReviews),
                        L(.levelsAndMore)
                    ],
                    expandedCardId: $expandedCardId
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.green.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.purple)
                    .font(.title3)
                Text(L(.levelsBenefitsTitle))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            Text(L(.levelsBenefitsDesc))
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(4)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.purple.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var errorSection: some View {
        Group {
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Data Loading

    private func loadUserData() async {
        guard let currentUser = supabase.auth.currentUser else {
            errorMessage = "Usuario no autenticado"
            return
        }

        do {
            let response = try await supabase.from("niveles")
                .select("level, current_xp, xp_to_next_level")
                .eq("id_usuario", value: currentUser.id.uuidString)
                .single()
                .execute()

            if !response.data.isEmpty,
               let dict = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] {

                let newLevel = dict["level"] as? Int ?? 1
                let newCurrentXP = dict["current_xp"] as? Int ?? 0
                let newXPToNextLevel = dict["xp_to_next_level"] as? Int ?? 100

                if let lastUpdate = lastUpdatedFromNotification,
                   Date().timeIntervalSince(lastUpdate) < 2 {
                    // mantener valores actuales si justo acabamos de recibir notificación
                } else {
                    level = newLevel
                    currentXP = newCurrentXP
                    xpToNextLevel = newXPToNextLevel
                }
            } else {
                level = 1; currentXP = 0; xpToNextLevel = 100
            }
        } catch {
            errorMessage = "Error al cargar datos de nivel: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
        }
    }
}

struct XPMethodCard: View {
    let id: String
    let icon: String
    let title: String
    let description: String
    let xpRange: String
    var details: [String]? = nil
    @Binding var expandedCardId: String?

    private var isExpanded: Bool {
        expandedCardId == id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                if details != nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        // Toggle: si está expandida, colapsar; sino, expandir esta y colapsar las demás
                        expandedCardId = isExpanded ? nil : id
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(description)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2) // Sin límite cuando está expandida
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(xpRange)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.green)

                        if details != nil {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded, let details = details {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(details, id: \.self) { detail in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green.opacity(0.7))
                                .frame(width: 6, height: 6)
                            Text(detail)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 42)
            }
        }
        .padding(14)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}
