import SwiftUI

/// Tipos de toast según el contexto
enum ToastType {
    case success
    case error
    case warning
    case info
    case achievement
    case xp
    case levelUp

    var backgroundColor: Color {
        switch self {
        case .success:
            return Color.green
        case .error:
            return Color.red
        case .warning:
            return Color.orange
        case .info:
            return Color.blue
        case .achievement:
            return Color.yellow
        case .xp:
            return Color.purple
        case .levelUp:
            return Color.green
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .achievement:
            return "trophy.fill"
        case .xp:
            return "star.fill"
        case .levelUp:
            return "arrow.up.circle.fill"
        }
    }
}

/// Modelo de un toast
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: Double

    init(type: ToastType, message: String, duration: Double = 3.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }
}

/// Vista individual de un toast
struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var iconRotation: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icono con animación especial para level up
            ZStack {
                if toast.type == .levelUp {
                    // Círculo de fondo brillante
                    Circle()
                        .fill(Color.white.opacity(Opacity.strong))
                        .frame(width: 40, height: 40)
                        .scaleEffect(scale * 1.2)
                }

                Image(systemName: toast.type.icon)
                    .font(toast.type == .levelUp ? .title2 : .title3)
                    .fontWeight(toast.type == .levelUp ? .bold : .regular)
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(iconRotation))
            }

            Text(toast.message)
                .font(toast.type == .levelUp ? .body : .subheadline)
                .fontWeight(toast.type == .levelUp ? .bold : .medium)
                .foregroundColor(.white)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(Opacity.strong))
            }
        }
        .paddingHorizontal()
        .paddingVertical()
        .background(
            ZStack {
                // Fondo base
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(backgroundGradient)
                    .shadowLarge()

                // Efecto shimmer para level up y XP
                if toast.type == .levelUp || toast.type == .xp {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(Opacity.semitransparent),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .mask(RoundedRectangle(cornerRadius: CornerRadius.lg))
                }
            }
        )
        .paddingHorizontal()
        .offset(y: offset)
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            // Feedback háptico según el tipo
            triggerHaptic()

            // Animación de entrada
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                offset = 0
                opacity = 1
                scale = 1.0
            }

            // Animación del icono para level up
            if toast.type == .levelUp {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                    iconRotation = 360
                }
            }

            // Efecto shimmer
            if toast.type == .levelUp || toast.type == .xp {
                withAnimation(.linear(duration: 1.5).delay(0.2)) {
                    shimmerOffset = 400
                }
            }

            // Auto dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                dismiss()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        offset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            offset = 0
                        }
                    }
                }
        )
    }

    private var backgroundGradient: LinearGradient {
        switch toast.type {
        case .levelUp:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(Opacity.strong)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .xp:
            return LinearGradient(
                colors: [Color.purple, Color.purple.opacity(Opacity.strong)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .achievement:
            return LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [toast.type.backgroundColor, toast.type.backgroundColor.opacity(Opacity.strong)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func triggerHaptic() {
        switch toast.type {
        case .success, .achievement, .levelUp:
            HapticFeedback.success()
        case .error:
            HapticFeedback.error()
        case .warning:
            HapticFeedback.warning()
        case .xp:
            HapticFeedback.light()
        case .info:
            HapticFeedback.soft()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            offset = -100
            opacity = 0
            scale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}
