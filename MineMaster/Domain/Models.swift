import Foundation

/// Rareté d'un item, du plus courant au plus rare.
///
/// - Authors: Axel L.
enum Rarity: String, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var id: String { rawValue }

    /// Rang de comparaison, `1` étant le plus courant.
    var rank: Int {
        switch self {
        case .common: 1
        case .uncommon: 2
        case .rare: 3
        case .epic: 4
        case .legendary: 5
        }
    }

    var displayName: String {
        switch self {
        case .common: "Commun"
        case .uncommon: "Peu commun"
        case .rare: "Rare"
        case .epic: "Épique"
        case .legendary: "Légendaire"
        }
    }

    /// Poids de tirage de base, sur un total de 100.
    var baseWeight: Double {
        switch self {
        case .common: 60
        case .uncommon: 25
        case .rare: 10
        case .epic: 4
        case .legendary: 1
        }
    }

    /// Poussière gagnée lorsqu'un doublon est obtenu.
    var dustValue: Int {
        switch self {
        case .common: 2
        case .uncommon: 4
        case .rare: 8
        case .epic: 20
        case .legendary: 50
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Catégorie fonctionnelle d'un item.
///
/// - Authors: Axel L.
enum ItemCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case block
    case tool
    case weapon
    case food
    case material
    case special
    case mob
    case armor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .block: "Bloc"
        case .tool: "Outil"
        case .weapon: "Arme"
        case .food: "Nourriture"
        case .material: "Matériau"
        case .special: "Spécial"
        case .mob: "Créature"
        case .armor: "Armure"
        }
    }

    var systemImage: String {
        switch self {
        case .block: "cube.fill"
        case .tool: "hammer.fill"
        case .weapon: "shield.fill"
        case .food: "leaf.fill"
        case .material: "square.stack.3d.up.fill"
        case .special: "sparkles"
        case .mob: "pawprint.fill"
        case .armor: "shield.lefthalf.filled"
        }
    }
}

/// Item du catalogue, indépendant de la persistance.
///
/// - Authors: Axel L.
struct CatalogItem: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let texturePath: String
    let rarity: Rarity
    let category: ItemCategory
    let stackSize: Int

    static func == (lhs: CatalogItem, rhs: CatalogItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Résultat d'un tirage dans un booster.
///
/// - Authors: Axel L.
struct DrawResult: Identifiable, Sendable {
    let item: CatalogItem
    let dust: Int
    let isNew: Bool

    var id: String { item.id }
}

/// Type de booster et ses règles de tirage.
///
/// - Authors: Axel L.
enum Booster: String, CaseIterable, Identifiable, Sendable {
    case common
    case rare
    case legendary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .common: "Booster Commun"
        case .rare: "Booster Rare"
        case .legendary: "Booster Légendaire"
        }
    }

    var subtitle: String {
        switch self {
        case .common: "Le bon départ pour remplir l'inventaire."
        case .rare: "Des matériaux solides et quelques pièces rares."
        case .legendary: "Les plus belles pièces de Minecraft."
        }
    }

    var symbol: String {
        switch self {
        case .common: "shippingbox.fill"
        case .rare: "cube.fill"
        case .legendary: "trophy.fill"
        }
    }

    var cardCount: Int { 5 }

    var guarantee: Rarity? {
        switch self {
        case .common: .uncommon
        case .rare: .rare
        case .legendary: .epic
        }
    }

    var guaranteeText: String {
        switch self {
        case .common: "1 Peu commun garanti"
        case .rare: "1 Rare garanti"
        case .legendary: "1 Épique garanti"
        }
    }

    /// Multiplicateur de poids appliqué à une rareté.
    ///
    /// - Parameter rarity: Rareté évaluée.
    /// - Returns: Facteur multiplicatif, `0` excluant la rareté du tirage.
    /// - Authors: Axel L.
    func multiplier(for rarity: Rarity) -> Double {
        switch (self, rarity) {
        case (.common, .rare): 0.5
        case (.common, .epic), (.common, .legendary): 0
        case (.rare, .rare): 2
        case (.rare, .epic): 1.5
        case (.rare, .legendary): 1
        case (.legendary, .rare): 3
        case (.legendary, .epic): 4
        case (.legendary, .legendary): 6
        default: 1
        }
    }
}

/// Erreur applicative exposable à l'interface.
///
/// - Authors: Axel L.
enum AppError: Error, Sendable, LocalizedError, Equatable {
    case offline
    case timeout
    case invalidResponse
    case decoding
    case imageUnavailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .offline: "Aucune connexion disponible."
        case .timeout: "Le serveur met trop de temps à répondre."
        case .invalidResponse: "Réponse invalide du serveur."
        case .decoding: "Les données reçues sont illisibles."
        case .imageUnavailable: "Image indisponible."
        case .rateLimited: "Trop de requêtes, réessaie dans un instant."
        }
    }
}
