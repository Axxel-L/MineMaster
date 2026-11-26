import Foundation

/// Rareté d'un item, du plus courant au plus rare.
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
/// L'égalité et le hachage reposent uniquement sur `id` : deux items de même
/// identifiant sont considérés identiques même si leurs métadonnées diffèrent.
struct CatalogItem: Identifiable, Hashable, Sendable {
    /// Identifiant technique, unique dans le catalogue, par exemple `oak_log`.
    let id: String
    /// Libellé affiché, déjà localisé si le catalogue distant le fournit.
    let displayName: String
    /// Chemin de texture relatif au CDN, validé par `ImagePolicy`.
    let texturePath: String
    /// Rareté, qui fixe le poids de tirage, la poussière et les prix du marché.
    let rarity: Rarity
    /// Catégorie fonctionnelle, utilisée par les filtres et les packs typés.
    let category: ItemCategory
    /// Taille de pile maximale annoncée par le catalogue.
    let stackSize: Int

    static func == (lhs: CatalogItem, rhs: CatalogItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Résultat d'un tirage dans un booster.
struct DrawResult: Identifiable, Sendable {
    /// Item tiré.
    let item: CatalogItem
    /// Poussière gagnée, `0` pour un item nouveau.
    let dust: Int
    /// `true` si l'item n'était pas encore possédé avant ce tirage.
    let isNew: Bool

    var id: String { item.id }
}

/// Type de booster et ses règles de tirage.
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

/// Type de contenu ciblé par un booster.
enum BoosterKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case mixed
    case creatures
    case weapons
    case armor
    case consumables
    case food
    case blocks
    case tools

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mixed: "Mélangé"
        case .creatures: "Créatures"
        case .weapons: "Armes"
        case .armor: "Armures"
        case .consumables: "Consommables"
        case .food: "Nourriture"
        case .blocks: "Blocs"
        case .tools: "Outils"
        }
    }

    var subtitle: String {
        switch self {
        case .mixed: "Un peu de tout le monde."
        case .creatures: "Des spécimens à collectionner."
        case .weapons: "Des lames et des projectiles."
        case .armor: "De quoi survivre au premier coup."
        case .consumables: "Des potions et des objets à usage unique."
        case .food: "De quoi tenir jusqu'au prochain biome."
        case .blocks: "Les matériaux du monde."
        case .tools: "Les outils qui font avancer la collection."
        }
    }

    var systemImage: String {
        switch self {
        case .mixed: "sparkles"
        case .creatures: "pawprint.fill"
        case .weapons: "shield.fill"
        case .armor: "shield.lefthalf.filled"
        case .consumables: "flask.fill"
        case .food: "leaf.fill"
        case .blocks: "cube.fill"
        case .tools: "hammer.fill"
        }
    }

    /// Filtre le catalogue sur le contenu de ce booster.
    ///
    /// - Parameter items: Catalogue complet.
    /// - Returns: Les items compatibles, ou le catalogue complet pour `.mixed`.
    func filter(_ items: [CatalogItem]) -> [CatalogItem] {
        guard let categories = categories else { return items }
        return items.filter { categories.contains($0.category) }
    }

    private var categories: Set<ItemCategory>? {
        switch self {
        case .mixed: nil
        case .creatures: [.mob]
        case .weapons: [.weapon]
        case .armor: [.armor]
        case .consumables: [.food, .special]
        case .food: [.food]
        case .blocks: [.block]
        case .tools: [.tool]
        }
    }
}

/// Plan d'ouverture tiré avant la déchirure du pack.
///
/// Fixé une seule fois par `GameStore.planOpening()` pour que le pack scellé
/// affiche exactement le type et la rareté qui seront ouverts.
struct OpeningPlan: Sendable {
    /// Booster dont dépendent les poids de tirage.
    let booster: Booster
    /// Type de contenu filtrant le catalogue.
    let kind: BoosterKind
}

/// Erreur applicative exposable à l'interface.
enum AppError: Error, Sendable, LocalizedError, Equatable {
    case offline
    case timeout
    case invalidResponse
    case decoding
    case imageUnavailable
    case rateLimited
    case insufficientDust
    case notOwned
    case outOfStock
    case rebirthLocked
    case authUnavailable
    case authInvalidInput
    case authInvalidCredentials
    case authEmailInUse
    case authWeakPassword
    case authNetwork
    case authTooManyRequests
    case authProviderDisabled
    case authGoogleNotConfigured
    case authUserDisabled
    case authAppNotAuthorized
    case authCancelled
    case authUnknown
    case storageUnavailable
    case syncRejected

    var errorDescription: String? {
        switch self {
        case .offline: "Tu es hors ligne."
        case .timeout: "Le serveur met trop de temps à répondre."
        case .invalidResponse: "Réponse invalide du serveur."
        case .decoding: "Impossible de charger le catalogue."
        case .imageUnavailable: "Image indisponible."
        case .rateLimited: "Trop de requêtes, réessaie dans un instant."
        case .insufficientDust: "Pas assez de poussière."
        case .notOwned: "Tu ne possèdes pas cet item."
        case .outOfStock: "Cet item n'est plus en vente."
        case .rebirthLocked: "Pas assez d'items pour renaître."
        case .authUnavailable: "Authentification indisponible. Vérifie GoogleService-Info.plist."
        case .authInvalidInput: "Vérifie l'email et le mot de passe."
        case .authInvalidCredentials: "Email ou mot de passe incorrect."
        case .authEmailInUse: "Un compte existe déjà avec cet email."
        case .authWeakPassword: "Mot de passe trop court : 8 caractères minimum."
        case .authNetwork: "Connexion impossible. Vérifie ton réseau."
        case .authTooManyRequests: "Trop de tentatives. Réessaie dans un instant."
        case .authProviderDisabled: "Ce fournisseur n'est pas activé dans la console Firebase."
        case .authGoogleNotConfigured: "Google n'est pas encore configuré. Active le fournisseur et son URL scheme."
        case .authUserDisabled: "Ce compte a été désactivé."
        case .authAppNotAuthorized: "Application non autorisée par Firebase. Vérifie la clé API et le bundle."
        case .authCancelled: "Connexion annulée."
        case .authUnknown: "Connexion impossible pour le moment."
        case .storageUnavailable: "Stockage local indisponible sur cet appareil."
        case .syncRejected: "Synchronisation refusée par le serveur. Vérifie les règles Firestore."
        }
    }
}
