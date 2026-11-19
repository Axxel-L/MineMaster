import Foundation

/// Titre d'explorateur débloqué par le nombre d'items uniques.
///
/// - Authors: Axel L.
enum ExplorerTitle: String, CaseIterable, Identifiable, Sendable {
    case novice
    case explorer
    case prospector
    case collector
    case artisan
    case legend
    case worldMaster

    var id: String { rawValue }

    /// Nombre d'items uniques requis pour débloquer le titre.
    var requiredItems: Int {
        switch self {
        case .novice: 0
        case .explorer: 15
        case .prospector: 50
        case .collector: 100
        case .artisan: 150
        case .legend: 200
        case .worldMaster: 254
        }
    }

    var displayName: String {
        switch self {
        case .novice: "Novice"
        case .explorer: "Explorateur"
        case .prospector: "Prospecteur"
        case .collector: "Collectionneur"
        case .artisan: "Artisan"
        case .legend: "Légende"
        case .worldMaster: "Maître du monde"
        }
    }

    var subtitle: String {
        switch self {
        case .novice: "Début de collection."
        case .explorer: "Tu découvres les bases."
        case .prospector: "Ta collection grandit."
        case .collector: "Tu connais bien le catalogue."
        case .artisan: "Une collection solide."
        case .legend: "Collectionneur confirmé."
        case .worldMaster: "Catalogue complet."
        }
    }

    var systemImage: String {
        switch self {
        case .novice: "figure.walk"
        case .explorer: "map.fill"
        case .prospector: "binoculars.fill"
        case .collector: "square.grid.2x2.fill"
        case .artisan: "hammer.fill"
        case .legend: "star.fill"
        case .worldMaster: "crown.fill"
        }
    }

    /// Titre courant pour un nombre d'items uniques.
    ///
    /// - Parameter uniqueCount: Nombre d'items distincts possédés.
    /// - Returns: Le titre le plus élevé dont le seuil est atteint.
    /// - Authors: Axel L.
    static func current(for uniqueCount: Int) -> ExplorerTitle {
        allCases.last { uniqueCount >= $0.requiredItems } ?? .novice
    }

    /// Titre suivant à débloquer.
    ///
    /// - Parameter uniqueCount: Nombre d'items distincts possédés.
    /// - Returns: Le prochain titre, ou `nil` si tous sont débloqués.
    /// - Authors: Axel L.
    static func next(for uniqueCount: Int) -> ExplorerTitle? {
        allCases.first { uniqueCount < $0.requiredItems }
    }
}
