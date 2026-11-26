import SwiftUI

/// En-tête discret partagé par les widgets.
struct WidgetHeader: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(WidgetTheme.accent)
            Text(title)
                .font(WidgetTheme.mono(7, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 2)
        }
        .accessibilityHidden(true)
    }
}

/// Anneau de progression avec pourcentage central.
struct WidgetProgressRing: View {
    let progress: Double
    var size: CGFloat = 82
    var lineWidth: CGFloat = 8

    private var clamped: Double {
        min(max(progress.isFinite ? progress : 0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetTheme.surfaceRaised, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [WidgetTheme.moss, WidgetTheme.accent, WidgetTheme.copper],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(clamped * 100))%")
                    .font(WidgetTheme.mono(size * 0.22, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("COLLECTION")
                    .font(WidgetTheme.mono(5.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(WidgetTheme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progression de collection")
        .accessibilityValue("\(Int(clamped * 100)) pour cent")
    }
}

/// Petite statistique à deux lignes.
struct WidgetMiniStat: View {
    let label: String
    let value: String
    var tint: Color = WidgetTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(WidgetTheme.mono(13, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(WidgetTheme.mono(6, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Échelle des titres d'explorateur.
struct WidgetTitleLadder: View {
    let rank: Int
    let count: Int

    private var boundedCount: Int {
        min(max(count, 1), 12)
    }

    private var boundedRank: Int {
        min(max(rank, 0), boundedCount - 1)
    }

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<boundedCount, id: \.self) { index in
                Capsule()
                    .fill(index <= boundedRank ? WidgetTheme.accent : WidgetTheme.surfaceRaised)
                    .frame(height: index == boundedRank ? 5 : 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Titre \(boundedRank + 1) sur \(boundedCount)")
    }
}

/// État affiché lorsqu'aucun compte n'a publié de statistiques.
struct WidgetEmptyView: View {
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("Ouvre MineMaster")
                .font(WidgetTheme.display(13, weight: .semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
            Text("Connecte-toi pour voir tes statistiques.")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
