import SwiftUI

// MARK: - Design System
// Sistema de diseño centralizado para mantener consistencia visual en toda la app

/// Tokens de espaciado siguiendo escala de 4 puntos
enum Spacing {
    /// 4pt - Espaciado extra pequeño (gaps internos)
    static let xs: CGFloat = 4

    /// 8pt - Espaciado pequeño (entre elementos relacionados)
    static let sm: CGFloat = 8

    /// 12pt - Espaciado medio (entre secciones relacionadas)
    static let md: CGFloat = 12

    /// 16pt - Espaciado estándar (padding horizontal principal)
    static let lg: CGFloat = 16

    /// 20pt - Espaciado grande (entre secciones)
    static let xl: CGFloat = 20

    /// 24pt - Espaciado extra grande (padding vertical de cards)
    static let xxl: CGFloat = 24

    /// 32pt - Espaciado máximo (separación de bloques principales)
    static let xxxl: CGFloat = 32
}

/// Corner radius estandarizados
enum CornerRadius {
    /// 8pt - Pequeño (badges, tags, chips)
    static let sm: CGFloat = 8

    /// 12pt - Medio (botones, inputs, cards pequeñas)
    static let md: CGFloat = 12

    /// 16pt - Grande (cards, sheets, modals)
    static let lg: CGFloat = 16

    /// 20pt - Extra grande (hero images, overlays principales)
    static let xl: CGFloat = 20

    /// 25pt - Search bars y elementos circulares
    static let pill: CGFloat = 25
}

/// Sombras estandarizadas
enum AppShadow {
    /// Sombra sutil para elementos elevados ligeramente
    static let sm = Shadow(
        color: Color.black.opacity(0.06),
        radius: 4,
        x: 0,
        y: 2
    )

    /// Sombra media para cards y botones
    static let md = Shadow(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )

    /// Sombra grande para modals y elementos flotantes
    static let lg = Shadow(
        color: Color.black.opacity(0.12),
        radius: 12,
        x: 0,
        y: 6
    )

    /// Sombra extra grande para elementos muy elevados
    static let xl = Shadow(
        color: Color.black.opacity(0.16),
        radius: 16,
        x: 0,
        y: 8
    )
}

/// Estructura auxiliar para definir sombras
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Tamaños de fuente estandarizados (preferir usar estilos nativos de SwiftUI)
enum FontSize {
    /// 12pt - Caption pequeño
    static let xs: CGFloat = 12

    /// 14pt - Caption, labels secundarios
    static let sm: CGFloat = 14

    /// 16pt - Body, inputs
    static let md: CGFloat = 16

    /// 18pt - Subtítulos, labels importantes
    static let lg: CGFloat = 18

    /// 20pt - Títulos de sección
    static let xl: CGFloat = 20

    /// 24pt - Títulos principales
    static let xxl: CGFloat = 24

    /// 28pt - Hero titles
    static let xxxl: CGFloat = 28

    /// 32pt - Display titles
    static let huge: CGFloat = 32
}

/// Pesos de fuente estandarizados
enum FontWeight {
    static let regular: Font.Weight = .regular
    static let medium: Font.Weight = .medium
    static let semibold: Font.Weight = .semibold
    static let bold: Font.Weight = .bold
    static let heavy: Font.Weight = .heavy
}

/// Tamaños de iconos
enum IconSize {
    /// 14pt - Iconos pequeños inline
    static let sm: CGFloat = 14

    /// 16pt - Iconos estándar en botones
    static let md: CGFloat = 16

    /// 20pt - Iconos destacados
    static let lg: CGFloat = 20

    /// 24pt - Iconos grandes en headers
    static let xl: CGFloat = 24

    /// 32pt - Iconos hero
    static let xxl: CGFloat = 32

    /// 48pt - Iconos de empty states
    static let huge: CGFloat = 48
}

/// Opacidades estandarizadas
enum Opacity {
    /// 0.05 - Overlay muy sutil
    static let subtle: Double = 0.05

    /// 0.1 - Background de estados hover
    static let light: Double = 0.1

    /// 0.15 - Background de cards secundarias
    static let medium: Double = 0.15

    /// 0.2 - Borders sutiles
    static let border: Double = 0.2

    /// 0.3 - Borders destacados, overlays
    static let strong: Double = 0.3

    /// 0.5 - Semi transparente
    static let semitransparent: Double = 0.5

    /// 0.6 - Disabled states
    static let disabled: Double = 0.6
}

/// Duraciones de animación estandarizadas
enum AnimationDuration {
    /// 0.15s - Micro interacciones (hover, press)
    static let instant: Double = 0.15

    /// 0.25s - Transiciones rápidas (fade, scale)
    static let fast: Double = 0.25

    /// 0.35s - Transiciones estándar
    static let normal: Double = 0.35

    /// 0.5s - Transiciones complejas
    static let slow: Double = 0.5
}

// MARK: - View Extensions

extension View {
    /// Aplica sombra pequeña
    func shadowSmall() -> some View {
        self.shadow(
            color: AppShadow.sm.color,
            radius: AppShadow.sm.radius,
            x: AppShadow.sm.x,
            y: AppShadow.sm.y
        )
    }

    /// Aplica sombra media
    func shadowMedium() -> some View {
        self.shadow(
            color: AppShadow.md.color,
            radius: AppShadow.md.radius,
            x: AppShadow.md.x,
            y: AppShadow.md.y
        )
    }

    /// Aplica sombra grande
    func shadowLarge() -> some View {
        self.shadow(
            color: AppShadow.lg.color,
            radius: AppShadow.lg.radius,
            x: AppShadow.lg.x,
            y: AppShadow.lg.y
        )
    }

    /// Aplica sombra extra grande
    func shadowXLarge() -> some View {
        self.shadow(
            color: AppShadow.xl.color,
            radius: AppShadow.xl.radius,
            x: AppShadow.xl.x,
            y: AppShadow.xl.y
        )
    }

    /// Aplica padding horizontal estándar
    func paddingHorizontal(_ size: CGFloat = Spacing.lg) -> some View {
        self.padding(.horizontal, size)
    }

    /// Aplica padding vertical estándar
    func paddingVertical(_ size: CGFloat = Spacing.lg) -> some View {
        self.padding(.vertical, size)
    }

    /// Card styling estándar
    func cardStyle(cornerRadius: CGFloat = CornerRadius.lg, shadow: Bool = true) -> some View {
        self
            .background(Color(UIColor.systemBackground))
            .cornerRadius(cornerRadius)
            .modifier(ConditionalShadow(enabled: shadow))
    }

    /// Secondary card styling (fondo secundario)
    func secondaryCardStyle(cornerRadius: CGFloat = CornerRadius.md) -> some View {
        self
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(cornerRadius)
    }
}

/// Modificador condicional para sombras
struct ConditionalShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.shadowMedium()
        } else {
            content
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Color primario de la app (azul)
    static let appPrimary = Color.blue

    /// Color de éxito (verde)
    static let appSuccess = Color.green

    /// Color de advertencia (naranja)
    static let appWarning = Color.orange

    /// Color de error (rojo)
    static let appError = Color.red

    /// Color de información (azul claro)
    static let appInfo = Color.blue.opacity(0.8)
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            // Spacing examples
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Spacing Scale")
                    .font(.headline)

                HStack(spacing: Spacing.xs) {
                    ForEach(["xs", "sm", "md", "lg", "xl", "xxl"], id: \.self) { size in
                        Text(size)
                            .font(.caption)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.blue.opacity(Opacity.light))
                            .cornerRadius(CornerRadius.sm)
                    }
                }
            }
            .padding()
            .cardStyle()

            // Corner Radius examples
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Corner Radius")
                    .font(.headline)

                HStack(spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(Color.blue)
                        .frame(width: 60, height: 60)
                        .overlay(Text("sm").foregroundColor(.white))

                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.green)
                        .frame(width: 60, height: 60)
                        .overlay(Text("md").foregroundColor(.white))

                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.orange)
                        .frame(width: 60, height: 60)
                        .overlay(Text("lg").foregroundColor(.white))

                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                        .overlay(Text("xl").foregroundColor(.white))
                }
            }
            .padding()
            .cardStyle()

            // Shadow examples
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Shadows")
                    .font(.headline)

                HStack(spacing: Spacing.lg) {
                    Text("SM")
                        .frame(width: 60, height: 60)
                        .secondaryCardStyle()
                        .shadowSmall()

                    Text("MD")
                        .frame(width: 60, height: 60)
                        .secondaryCardStyle()
                        .shadowMedium()

                    Text("LG")
                        .frame(width: 60, height: 60)
                        .secondaryCardStyle()
                        .shadowLarge()

                    Text("XL")
                        .frame(width: 60, height: 60)
                        .secondaryCardStyle()
                        .shadowXLarge()
                }
            }
            .padding()
            .cardStyle(shadow: false)
        }
        .paddingHorizontal()
        .paddingVertical()
    }
}
