import WidgetKit

/// Entrée de timeline commune aux widgets iPhone.
struct MineMasterWidgetEntry: TimelineEntry {
    let date: Date
    let state: ComplicationState?
}

/// Fournit l'état borné écrit par l'application.
struct MineMasterWidgetProvider: TimelineProvider {
    private let placeholderState: ComplicationState

    init(placeholderState: ComplicationState = .placeholder) {
        self.placeholderState = placeholderState
    }

    func placeholder(in context: Context) -> MineMasterWidgetEntry {
        MineMasterWidgetEntry(date: .now, state: placeholderState)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (MineMasterWidgetEntry) -> Void
    ) {
        completion(
            MineMasterWidgetEntry(
                date: .now,
                state: context.isPreview
                    ? placeholderState
                    : (ComplicationStore.load() ?? placeholderState)
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<MineMasterWidgetEntry>) -> Void
    ) {
        let entry = MineMasterWidgetEntry(date: .now, state: ComplicationStore.load())
        let next = Date.now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension ComplicationState {
    /// Exemple affiché dans la galerie et avant la première connexion.
    static let placeholder = ComplicationState(
        progress: 0.42,
        dust: 120,
        title: "Explorateur",
        nextTitle: "Prospecteur",
        uniqueCount: 215,
        totalItems: 515,
        totalOpened: 27,
        rebirthLevel: 2,
        titleRank: 1,
        titleCount: 7,
        updatedAt: .now
    )
}
