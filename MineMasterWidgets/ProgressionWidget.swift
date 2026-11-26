import SwiftUI
import WidgetKit

/// Widget de progression, d'items uniques et de poussière.
struct ProgressionWidget: Widget {
    private let kind = "MineMasterProgression"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MineMasterWidgetProvider()) { entry in
            ProgressionWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Progression")
        .description("Ta collection, tes items uniques et ta poussière.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Rendu du widget de progression selon sa taille.
struct ProgressionWidgetView: View {
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
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(systemImage: "cube.fill", title: "PROGRESSION")

            HStack(spacing: 10) {
                WidgetProgressRing(progress: state.progress, size: 76, lineWidth: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(state.uniqueCount)")
                        .font(WidgetTheme.display(30, weight: .heavy))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("sur \(state.totalItems)")
                        .font(WidgetTheme.mono(8, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(WidgetTheme.copper)
                        Text("\(state.dust)")
                            .font(WidgetTheme.mono(10, weight: .bold))
                            .foregroundStyle(WidgetTheme.copper)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func medium(_ state: ComplicationState) -> some View {
        HStack(spacing: 14) {
            WidgetProgressRing(progress: state.progress, size: 94, lineWidth: 8)

            VStack(alignment: .leading, spacing: 5) {
                WidgetHeader(systemImage: "cube.fill", title: "PROGRESSION")

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(state.title)
                        .font(WidgetTheme.display(17, weight: .heavy))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    if let nextTitle = state.nextTitle {
                        Text("→ \(nextTitle)")
                            .font(WidgetTheme.mono(7, weight: .bold))
                            .foregroundStyle(WidgetTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                WidgetTitleLadder(rank: state.titleRank, count: state.titleCount)

                Spacer(minLength: 2)

                HStack(alignment: .top, spacing: 12) {
                    WidgetMiniStat(
                        label: "ITEMS",
                        value: "\(state.uniqueCount)/\(state.totalItems)",
                        tint: WidgetTheme.accent
                    )
                    WidgetMiniStat(
                        label: "POUSSIÈRE",
                        value: "\(state.dust)",
                        tint: WidgetTheme.copper
                    )
                    WidgetMiniStat(
                        label: "OUVERTURES",
                        value: "\(state.totalOpened)"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
