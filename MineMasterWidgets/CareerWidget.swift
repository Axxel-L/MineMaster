import SwiftUI
import WidgetKit

/// Widget du titre, des ouvertures et des renaissances.
struct CareerWidget: Widget {
    private let kind = "MineMasterCareer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MineMasterWidgetProvider()) { entry in
            CareerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Carrière")
        .description("Ton titre d'explorateur, tes ouvertures et tes renaissances.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Rendu du widget de carrière selon sa taille.
struct CareerWidgetView: View {
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
        .widgetURL(WidgetLink.profile)
    }

    private func small(_ state: ComplicationState) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            WidgetHeader(systemImage: "figure.walk", title: "CARRIÈRE")

            Text(state.title)
                .font(WidgetTheme.display(22, weight: .heavy))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            WidgetTitleLadder(rank: state.titleRank, count: state.titleCount)

            Spacer(minLength: 2)

            HStack(alignment: .bottom, spacing: 8) {
                WidgetMiniStat(
                    label: "OUVERTURES",
                    value: "\(state.totalOpened)",
                    tint: WidgetTheme.accent
                )
                Spacer(minLength: 4)
                WidgetMiniStat(
                    label: "RENAISSANCES",
                    value: "\(state.rebirthLevel)",
                    tint: WidgetTheme.copper
                )
            }
        }
    }

    private func medium(_ state: ComplicationState) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                WidgetHeader(systemImage: "figure.walk", title: "CARRIÈRE")

                Text(state.title)
                    .font(WidgetTheme.display(28, weight: .heavy))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let nextTitle = state.nextTitle {
                    Text("Prochain titre · \(nextTitle)")
                        .font(WidgetTheme.mono(7, weight: .bold))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)
                }

                WidgetTitleLadder(rank: state.titleRank, count: state.titleCount)

                Spacer(minLength: 2)

                Text("\(state.uniqueCount) items uniques")
                    .font(WidgetTheme.mono(8, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 10) {
                WidgetMiniStat(
                    label: "OUVERTURES",
                    value: "\(state.totalOpened)",
                    tint: WidgetTheme.accent
                )
                WidgetMiniStat(
                    label: "RENAISSANCES",
                    value: "\(state.rebirthLevel)",
                    tint: WidgetTheme.copper
                )
                WidgetMiniStat(
                    label: "POUSSIÈRE",
                    value: "\(state.dust)",
                    tint: WidgetTheme.textPrimary
                )
            }
            .frame(maxWidth: 96, alignment: .trailing)
        }
    }
}
