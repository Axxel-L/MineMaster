import SwiftUI

/// Jetons de design de l'application.
///
/// - Authors: Axel L.
enum Theme {
    static let accent = Color(red: 0.36, green: 0.85, blue: 0.48)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let stroke = Color.white.opacity(0.10)
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
        case .common: Color(red: 0.45, green: 0.78, blue: 0.56)
        case .rare: Rarity.rare.color
        case .legendary: Rarity.legendary.color
        }
    }
}

/// Fond principal de l'application.
///
/// - Authors: Axel L.
struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.04)
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.55, 0.5), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ],
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.08),
                    Color(red: 0.03, green: 0.08, blue: 0.06),
                    Color(red: 0.02, green: 0.05, blue: 0.04),
                    Color(red: 0.06, green: 0.16, blue: 0.10),
                    Color(red: 0.10, green: 0.26, blue: 0.16),
                    Color(red: 0.04, green: 0.10, blue: 0.07),
                    Color(red: 0.02, green: 0.05, blue: 0.04),
                    Color(red: 0.05, green: 0.14, blue: 0.09),
                    Color(red: 0.03, green: 0.07, blue: 0.05)
                ]
            )
            .overlay(Color.black.opacity(0.15))
        }
        .ignoresSafeArea()
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
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isActive ? Color.black.opacity(0.85) : Theme.textSecondary)
                .background(isActive ? tint : Color.white.opacity(0.07), in: Capsule())
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

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else if failed {
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.24)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .shimmering()
            }
        }
        .frame(width: size, height: size)
        .task(id: item.texturePath) {
            await load()
        }
        .accessibilityLabel(item.displayName)
    }

    private func load() async {
        guard let url = ImagePolicy.url(for: item.texturePath) else {
            failed = true
            return
        }
        do {
            let data = try await ImagePipeline.shared.data(for: url)
            guard let decoded = UIImage(data: data) else {
                failed = true
                return
            }
            image = decoded
            failed = false
        } catch {
            failed = true
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.tint(tint.opacity(0.12)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
