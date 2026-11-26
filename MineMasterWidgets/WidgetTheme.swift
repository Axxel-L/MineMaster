import SwiftUI

/// Jetons visuels partagés par les widgets iPhone.
enum WidgetTheme {
    static let accent = Color(red: 0.36, green: 0.84, blue: 0.58)
    static let moss = Color(red: 0.29, green: 0.66, blue: 0.55)
    static let copper = Color(red: 0.93, green: 0.63, blue: 0.32)
    static let background = Color(red: 0.043, green: 0.067, blue: 0.078)
    static let surfaceRaised = Color(red: 0.102, green: 0.145, blue: 0.157)
    static let textPrimary = Color(red: 0.94, green: 0.94, blue: 0.90)
    static let textSecondary = Color(red: 0.62, green: 0.68, blue: 0.67)

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Fond ardoise commun aux trois widgets.
struct WidgetBackground: View {
    var body: some View {
        ZStack {
            WidgetTheme.background
            RadialGradient(
                colors: [WidgetTheme.moss.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 220
            )
            RadialGradient(
                colors: [WidgetTheme.copper.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 2,
                endRadius: 200
            )
        }
    }
}
