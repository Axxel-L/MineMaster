import SwiftUI
import WidgetKit

/// Entrée de timeline de la complication.
struct MineMasterComplicationEntry: TimelineEntry {
    let date: Date
    let state: ComplicationState?
}

/// Fournit l'état partagé par l'application.
struct MineMasterComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> MineMasterComplicationEntry {
        MineMasterComplicationEntry(
            date: .now,
            state: ComplicationState(
                progress: 0.42,
                dust: 120,
                title: "Explorateur",
                nextTitle: "Prospecteur",
                updatedAt: .now
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (MineMasterComplicationEntry) -> Void
    ) {
        completion(MineMasterComplicationEntry(date: .now, state: ComplicationStore.load()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<MineMasterComplicationEntry>) -> Void
    ) {
        let entry = MineMasterComplicationEntry(date: .now, state: ComplicationStore.load())
        let next = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// Complication de progression, poussière et titre.
struct MineMasterComplication: Widget {
    private let kind = "MineMasterComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MineMasterComplicationProvider()) { entry in
            MineMasterComplicationView(entry: entry)
        }
        .configurationDisplayName("MineMaster")
        .description("Progression, poussière et titre d'explorateur.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Rendu de la complication selon sa famille.
struct MineMasterComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MineMasterComplicationEntry

    private enum Palette {
        static let accent = Color(red: 0.36, green: 0.84, blue: 0.58)
        static let muted = Color(red: 0.62, green: 0.68, blue: 0.67)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
        default:
            circular
        }
    }

    private var circular: some View {
        Gauge(value: entry.state?.progress ?? 0) {
            Image(systemName: "cube.fill")
        } currentValueLabel: {
            Text(entry.state.map { "\(Int($0.progress * 100))%" } ?? "—")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Palette.accent)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "cube.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("MineMaster")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                Spacer(minLength: 2)
                Text(entry.state.map { "\(Int($0.progress * 100))%" } ?? "—")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
            if let state = entry.state {
                Text(state.title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                ProgressView(value: state.progress)
                    .tint(Palette.accent)
                if let nextTitle = state.nextTitle {
                    Text("→ \(nextTitle)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Text("\(state.dust) poussière")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            } else {
                Text("Ouvre l'app iPhone")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text(entry.state.map { "MineMaster \(Int($0.progress * 100)) % · \($0.dust) poussière" } ?? "MineMaster")
    }
}
