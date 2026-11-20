import SwiftUI

/// Puce de poussière compacte de la montre.
struct WatchDustPill: View {
    let dust: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 8, weight: .bold))
            Text("\(dust)")
                .font(Theme.mono(10, weight: .bold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.accent.opacity(0.12), in: Capsule())
        .accessibilityIdentifier("watch-dust-pill")
        .accessibilityLabel("\(dust) poussière")
    }
}

/// Ligne de navigation du menu principal.
struct WatchDestinationRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(9)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

/// Illustration compacte du pack scellé.
struct WatchBoosterArt: View {
    let booster: Booster
    var kind: BoosterKind?

    private var colors: [Color] {
        kind?.foilColors ?? booster.foilColors
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            LinearGradient(
                colors: [.white.opacity(0.22), .clear, .black.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 2) {
                Text("MINEMASTER")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.black.opacity(0.55))
                Spacer(minLength: 0)
                Image(systemName: kind?.systemImage ?? "cube.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 2, y: 2)
                Text("MINE")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("MASTER")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(.black.opacity(0.72))
                if let kind {
                    Text(kind.packLabel)
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.black.opacity(0.74))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.42), in: Capsule())
                }
                Spacer(minLength: 0)
                Text("5 CARTES")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.black.opacity(0.6))
            }
            .padding(8)
        }
        .frame(width: 116, height: 152)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: (kind?.tint ?? booster.tint).opacity(0.32), radius: 12, y: 7)
        .rotationEffect(.degrees(-1.5))
        .accessibilityLabel("Pack \(kind?.displayName ?? "Mystère")")
    }
}

/// Carte de révélation compacte, retournée au toucher.
struct WatchRevealCard: View {
    let result: DrawResult
    let position: Int
    let isRevealed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                back
                    .opacity(isRevealed ? 0 : 1)
                front
                    .opacity(isRevealed ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 186)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(result.item.rarity.color.opacity(isRevealed ? 0.20 : 0.08))
                    .blur(radius: isRevealed ? 18 : 8)
            }
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        result.item.rarity.color.opacity(isRevealed ? 0.62 : 0.24),
                        lineWidth: isRevealed ? 1.2 : 0.7
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("watch-card-\(position)")
        .accessibilityLabel(isRevealed ? result.item.displayName : "Carte non révélée")
        .accessibilityValue(
            isRevealed
                ? "\(result.item.rarity.displayName), \(result.dust) poussière"
                : "Touche pour révéler"
        )
    }

    private var front: some View {
        VStack(spacing: 5) {
            HStack {
                RarityBadge(rarity: result.item.rarity)
                Spacer(minLength: 2)
                Text(result.item.category.displayName)
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            ItemImageView(item: result.item, size: 54)
            Text(result.item.displayName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            if result.isNew || result.dust > 0 {
                HStack(spacing: 4) {
                    if result.isNew {
                        Label("NOUVEAU", systemImage: "sparkles")
                            .foregroundStyle(Theme.accent)
                    }
                    if result.dust > 0 {
                        Label("+\(result.dust)", systemImage: "circle.hexagongrid.fill")
                            .foregroundStyle(Rarity.epic.color)
                    }
                }
                .font(.system(size: 7, weight: .bold, design: .monospaced))
            }
            Spacer(minLength: 0)
        }
        .padding(9)
    }

    private var back: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Scellé")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                Spacer()
                Text("?")
                    .font(Theme.mono(8, weight: .bold))
            }
            .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Image(systemName: "cube.fill")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.textSecondary.opacity(0.65))
            Text("Touche pour révéler")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(9)
    }
}

/// Écran de chargement compact.
struct WatchLoadingView: View {
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 8) {
                Text("MineMaster")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                ProgressView()
                    .tint(Theme.accent)
                Text("Catalogue")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// Ligne d'information d'une fiche item ou du profil.
struct WatchInfoRow: View {
    let title: String
    let value: String
    var tint: Color = Theme.textPrimary

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
