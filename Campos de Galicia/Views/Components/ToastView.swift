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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.title3)
                .foregroundColor(.white)

            Text(toast.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            toast.type.backgroundColor
                .opacity(0.95)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = 0
                opacity = 1
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

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            offset = -100
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}
