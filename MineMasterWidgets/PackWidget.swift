import SwiftUI
import WidgetKit

/// Widget d'accès rapide à l'ouverture d'un pack.
struct PackWidget: Widget {
    private let kind = "MineMasterPack"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MineMasterWidgetProvider()) { entry in
            PackWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Ouvrir un pack")
        .description("Accès rapide à l'ouverture d'un booster.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Rendu du widget d'accès rapide selon sa taille.
struct PackWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MineMasterWidgetEntry

    var body: some View {
        Group {
            if let state = entry.state {
                switch family {
                case .systemMedium:
                    medium(state)
                default:
                    small(state)
                }
            } else {
                WidgetEmptyView()
            }
        }
        .widgetURL(WidgetLink.boosters)
    }

    private func small(_ state: ComplicationState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(systemImage: "shippingbox.fill", title: "PACK MYSTÈRE")

            Spacer(minLength: 4)

            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prêt à ouvrir")
                        .font(WidgetTheme.display(15, weight: .heavy))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("5 cartes par pack")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(WidgetTheme.copper)
            }

            Spacer(minLength: 4)

            Text("\(state.uniqueCount) / \(state.totalItems) items")
                .font(WidgetTheme.mono(8, weight: .bold))
                .foregroundStyle(WidgetTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func medium(_ state: ComplicationState) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                WidgetHeader(systemImage: "shippingbox.fill", title: "PACK MYSTÈRE")

                Text("Ouvre un booster")
                    .font(WidgetTheme.display(25, weight: .heavy))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("5 cartes · rareté garantie")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                HStack(spacing: 7) {
                    ProgressView(value: state.progress)
                        .tint(WidgetTheme.accent)
                    Text("\(state.uniqueCount)/\(state.totalItems)")
                        .font(WidgetTheme.mono(8, weight: .bold))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WidgetTheme.copper.opacity(0.30),
                                WidgetTheme.copper.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(WidgetTheme.copper.opacity(0.35), lineWidth: 0.8)
                    }
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(WidgetTheme.copper)
            }
            .frame(width: 88)
        }
    }
}
