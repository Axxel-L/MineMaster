import Foundation
import Observation

/// Onglet demandé par un lien profond entrant.
@Observable
@MainActor
final class AppRoute {
    /// Schéma d'URL accepté par l'application.
    nonisolated static let scheme = "minemaster"

    /// Onglet sélectionné dans la barre principale.
    var selectedTab = "packs"

    /// Applique un lien profond aux onglets connus.
    ///
    /// Les URL d'un autre schéma, sans hôte ou vers une destination inconnue
    /// sont ignorées. Un lien reçu avant la connexion reste mémorisé jusqu'à
    /// l'affichage de l'application.
    ///
    /// - Parameter url: URL reçue par l'application.
    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return }
        switch url.host?.lowercased() {
        case "boosters", "packs":
            selectedTab = "packs"
        case "profile", "stats":
            selectedTab = "profile"
        case "collection":
            selectedTab = "collection"
        case "market":
            selectedTab = "market"
        default:
            break
        }
    }
}
