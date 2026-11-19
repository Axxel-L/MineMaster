import SwiftUI

/// Jetons de design de l'application.
///
/// - Authors: Axel L.
enum Theme {
    static let accent = Color(red: 0.95, green: 0.66, blue: 0.24)
    static let moss = Color(red: 0.42, green: 0.72, blue: 0.42)
    static let copper = Color(red: 0.86, green: 0.47, blue: 0.26)
    static let background = Color(red: 0.055, green: 0.05, blue: 0.04)
    static let surface = Color(red: 0.085, green: 0.078, blue: 0.062)
    static let surfaceRaised = Color(red: 0.12, green: 0.108, blue: 0.086)
    static let textPrimary = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let textSecondary = Color(red: 0.68, green: 0.64, blue: 0.55)
    static let stroke = Color(red: 0.92, green: 0.78, blue: 0.48).opacity(0.18)
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24
    static let spaceXL: CGFloat = 32
    static let spaceXXL: CGFloat = 48
    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 24

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Rarity {
    /// Couleur d'accent de la rareté.
    var color: Color {
        switch self {
        case .common: Color(red: 0.60, green: 0.63, blue: 0.65)
        case .uncommon: Color(red: 0.30, green: 0.69, blue: 0.31)
        case .rare: Color(red: 0.23, green: 0.51, blue: 0.96)
        case .epic: Color(red: 0.66, green: 0.33, blue: 0.97)
        case .legendary: Color(red: 0.96, green: 0.70, blue: 0.00)
        }
    }

    /// Dégradé de carte associé à la rareté.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.55), color.opacity(0.10), Color.black.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Booster {
    var tint: Color {
        switch self {
        case .common: Theme.moss
        case .rare: Theme.copper
        case .legendary: Theme.accent
        }
    }

    /// Couleurs de feuille du pack, du plus sombre au plus lumineux.
    var foilColors: [Color] {
        switch self {
        case .common: [Color(red: 0.10, green: 0.42, blue: 0.20), Color(red: 0.30, green: 0.68, blue: 0.34), Color(red: 0.78, green: 0.90, blue: 0.48)]
        case .rare: [Color(red: 0.48, green: 0.16, blue: 0.07), Color(red: 0.88, green: 0.40, blue: 0.16), Color(red: 1.00, green: 0.68, blue: 0.28)]
        case .legendary: [Color(red: 0.55, green: 0.30, blue: 0.03), Color(red: 0.95, green: 0.62, blue: 0.12), Color(red: 1.00, green: 0.86, blue: 0.42)]
        }
    }
}

/// Fond principal de l'application.
///
/// - Authors: Axel L.
struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.moss.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [Theme.accent.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 480
            )
            GrainOverlay()
        }
        .ignoresSafeArea()
    }
}

private struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 26
            let columns = Int(size.width / step) + 1
            let rows = Int(size.height / step) + 1
            for column in 0..<columns {
                for row in 0..<rows {
                    let seed = (column &* 73856093) ^ (row &* 19349663)
                    guard seed % 11 == 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(column) * step,
                        y: CGFloat(row) * step,
                        width: 2,
                        height: 2
                    )
                    context.fill(Path(rect), with: .color(.white.opacity(0.018)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Badge de rareté.
///
/// - Authors: Axel L.
struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.displayName.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(0.7)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(rarity.color)
            .background(rarity.color.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(rarity.color.opacity(0.45), lineWidth: 0.5))
            .accessibilityLabel("Rareté \(rarity.displayName)")
    }
}

/// Puce de filtre de collection.
///
/// - Authors: Axel L.
struct FilterChip: View {
    let title: String
    let isActive: Bool
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Theme.mono(10, weight: .bold))
                .tracking(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isActive ? Theme.background : Theme.textSecondary)
                .background(isActive ? tint : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(isActive ? .clear : Theme.stroke, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Effet de chargement progressif.
///
/// - Authors: Axel L.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .rotationEffect(.degrees(18))
                        .offset(x: phase * proxy.size.width)
                    }
                    .allowsHitTesting(false)
                    .clipped()
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    /// Applique un balayage lumineux de chargement.
    ///
    /// - Returns: La vue animée.
    /// - Authors: Axel L.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Image d'item chargée à distance avec squelette et repli.
///
/// - Authors: Axel L.
struct ItemImageView: View {
    let item: CatalogItem
    var size: CGFloat = 56

    private enum LoadState {
        case loading
        case loaded(UIImage)
        case failed
    }

    @State private var state: LoadState = .loading

    var body: some View {
        Group {
            switch state {
            case let .loaded(image):
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            case .failed:
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.24)
                    .foregroundStyle(Theme.textSecondary)
            case .loading:
                SkeletonImage(size: size)
            }
        }
        .frame(width: size, height: size)
        .task(id: item.texturePath) {
            state = .loading
            await load()
        }
        .accessibilityLabel(item.displayName)
    }

    private func load() async {
        let candidates = [
            MobRenderAPI.url(for: item.id),
            ImagePolicy.url(for: item.texturePath)
        ].compactMap { $0 }

        for url in candidates {
            do {
                let data = try await ImagePipeline.shared.data(for: url)
                if let decoded = UIImage(data: data) {
                    state = .loaded(decoded)
                    return
                }
            } catch {
                continue
            }
        }
        state = .failed
    }
}

/// Squelette rectangulaire d'une image en attente de téléchargement.
///
/// - Authors: Axel L.
struct SkeletonImage: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(Theme.surfaceRaised)
            .frame(width: size, height: size)
            .shimmering()
            .accessibilityHidden(true)
    }
}

/// Squelette d'une carte de booster.
///
/// - Authors: Axel L.
struct SkeletonBooster: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)).frame(width: 34, height: 34)
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)).frame(width: 170, height: 20)
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(height: 14)
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(width: 220, height: 14)
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(height: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shimmering()
        .accessibilityHidden(true)
    }
}

/// Squelette d'une grille de collection.
///
/// - Authors: Axel L.
struct SkeletonGrid: View {
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<9, id: \.self) { _ in
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)).frame(width: 58, height: 58)
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(width: 64, height: 11)
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(width: 42, height: 9)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .shimmering()
        .accessibilityHidden(true)
    }
}

/// Carte de statistique.
///
/// - Authors: Axel L.
struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased())
                    .font(Theme.mono(9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(Theme.display(30))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.5)
        }
    }
}

/// État vide illustré avec une icône Heroicons.
///
/// - Authors: Axel L.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
