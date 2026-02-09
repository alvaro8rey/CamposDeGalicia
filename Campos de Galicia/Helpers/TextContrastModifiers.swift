import SwiftUI

/// Modifiers para mejorar la legibilidad de texto sobre imágenes

struct TextShadowModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}

struct TextStrokeModifier: ViewModifier {
    let width: CGFloat
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .foregroundColor(color)
                    .offset(x: -width, y: -width)
            )
            .overlay(
                content
                    .foregroundColor(color)
                    .offset(x: width, y: width)
            )
    }
}

struct HighContrastTextModifier: ViewModifier {
    enum ContrastStyle {
        case light      // Para fondos oscuros
        case dark       // Para fondos claros
        case strong     // Contraste máximo
        case subtle     // Contraste sutil
    }

    let style: ContrastStyle

    func body(content: Content) -> some View {
        switch style {
        case .light:
            content
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.8), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
        case .dark:
            content
                .foregroundColor(.black)
                .shadow(color: Color.white.opacity(0.8), radius: 4, x: 0, y: 2)
                .shadow(color: Color.white.opacity(0.5), radius: 8, x: 0, y: 4)
        case .strong:
            content
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(1.0), radius: 2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
                .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 6)
        case .subtle:
            content
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
        }
    }
}

struct GlassmorphicBackgroundModifier: ViewModifier {
    let tintColor: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tintColor.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

extension View {
    /// Añade sombra suave para mejorar legibilidad
    func textShadow(radius: CGFloat = 4, opacity: Double = 0.6) -> some View {
        modifier(TextShadowModifier(radius: radius, opacity: opacity))
    }

    /// Añade stroke/borde al texto
    func textStroke(width: CGFloat = 1, color: Color = .black) -> some View {
        modifier(TextStrokeModifier(width: width, color: color))
    }

    /// Aplica contraste alto automáticamente según el estilo
    func highContrast(_ style: HighContrastTextModifier.ContrastStyle = .light) -> some View {
        modifier(HighContrastTextModifier(style: style))
    }

    /// Añade fondo glassmorphic para mejorar legibilidad
    func glassmorphicBackground(tintColor: Color = .black, cornerRadius: CGFloat = 8) -> some View {
        modifier(GlassmorphicBackgroundModifier(tintColor: tintColor, cornerRadius: cornerRadius))
    }
}

/// Background oscuro con gradiente para mejorar contraste de textos
struct DarkGradientOverlay: View {
    let opacity: Double
    let startPoint: UnitPoint
    let endPoint: UnitPoint

    init(
        opacity: Double = 0.6,
        from startPoint: UnitPoint = .center,
        to endPoint: UnitPoint = .bottom
    ) {
        self.opacity = opacity
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0),
                Color.black.opacity(opacity)
            ]),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}
