import Foundation
import WidgetKit

/// Publie un état borné vers les widgets iPhone.
@MainActor
enum WidgetStatePublisher {
    /// Construit l'instantané partagé à partir du magasin courant.
    ///
    /// - Parameters:
    ///   - store: Magasin dont les compteurs sont exportés.
    ///   - updatedAt: Date de référence de l'instantané.
    /// - Returns: Un état borné, sans identifiant de compte.
    static func makeState(from store: GameStore, updatedAt: Date = .now) -> ComplicationState {
        let title = store.explorerTitle
        return ComplicationState(
            progress: store.progress,
            dust: store.dust,
            title: title.displayName,
            nextTitle: store.nextExplorerTitle?.displayName,
            uniqueCount: store.uniqueCount,
            totalItems: store.catalog.count,
            totalOpened: store.totalOpened,
            rebirthLevel: store.rebirthLevel,
            titleRank: ExplorerTitle.allCases.firstIndex(of: title) ?? 0,
            titleCount: ExplorerTitle.allCases.count,
            updatedAt: updatedAt
        )
    }

    /// Écrit l'état courant et demande le rafraîchissement des widgets.
    ///
    /// - Parameter store: Magasin dont les compteurs sont exportés.
    static func publish(from store: GameStore) {
        ComplicationStore.save(makeState(from: store))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Efface l'état partagé après une déconnexion.
    static func clear() {
        ComplicationStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
