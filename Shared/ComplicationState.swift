import Foundation

/// Données minimales partagées avec la complication et les widgets iPhone.
nonisolated struct ComplicationState: Codable, Sendable, Equatable {
    /// Plafond de poussière aligné sur les règles Firestore.
    static let maximumDust = 1_000_000_000
    /// Plafond du nombre d'items du catalogue.
    static let maximumItems = 10_000
    /// Plafond du nombre d'ouvertures.
    static let maximumOpenings = 1_000_000_000
    /// Plafond du niveau de renaissance.
    static let maximumRebirthLevel = 1_000_000

    let progress: Double
    let dust: Int
    let title: String
    let nextTitle: String?
    let uniqueCount: Int
    let totalItems: Int
    let totalOpened: Int
    let rebirthLevel: Int
    let titleRank: Int
    let titleCount: Int
    let updatedAt: Date

    /// Construit un état borné pour la complication et les widgets.
    ///
    /// - Parameters:
    ///   - progress: Progression entre `0` et `1`.
    ///   - dust: Poussière du compte.
    ///   - title: Titre d'explorateur courant.
    ///   - nextTitle: Prochain titre, `nil` au dernier palier.
    ///   - uniqueCount: Nombre d'items distincts possédés.
    ///   - totalItems: Nombre d'items du catalogue.
    ///   - totalOpened: Nombre d'ouvertures enregistrées.
    ///   - rebirthLevel: Niveau de renaissance courant.
    ///   - titleRank: Rang du titre courant, à partir de `0`.
    ///   - titleCount: Nombre de titres disponibles.
    ///   - updatedAt: Date de dernière synchronisation.
    init(
        progress: Double,
        dust: Int,
        title: String,
        nextTitle: String? = nil,
        uniqueCount: Int = 0,
        totalItems: Int = 0,
        totalOpened: Int = 0,
        rebirthLevel: Int = 0,
        titleRank: Int = 0,
        titleCount: Int = 7,
        updatedAt: Date
    ) {
        let boundedTotal = min(max(totalItems, 0), Self.maximumItems)
        let boundedTitleCount = min(max(titleCount, 1), 20)
        self.progress = min(max(progress.isFinite ? progress : 0, 0), 1)
        self.dust = min(max(dust, 0), Self.maximumDust)
        self.title = String(title.prefix(40))
        self.nextTitle = nextTitle.map { String($0.prefix(40)) }
        self.uniqueCount = min(max(uniqueCount, 0), boundedTotal)
        self.totalItems = boundedTotal
        self.totalOpened = min(max(totalOpened, 0), Self.maximumOpenings)
        self.rebirthLevel = min(max(rebirthLevel, 0), Self.maximumRebirthLevel)
        self.titleRank = min(max(titleRank, 0), boundedTitleCount - 1)
        self.titleCount = boundedTitleCount
        self.updatedAt = updatedAt
    }

    /// Décode un état en bornant toutes les valeurs.
    ///
    /// Les champs de statistiques absents d'une ancienne charge utile prennent
    /// la valeur `0`, ce qui permet de conserver un état déjà écrit.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si un champ obligatoire manque.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            progress: try container.decode(Double.self, forKey: .progress),
            dust: try container.decode(Int.self, forKey: .dust),
            title: try container.decode(String.self, forKey: .title),
            nextTitle: try container.decodeIfPresent(String.self, forKey: .nextTitle),
            uniqueCount: try container.decodeIfPresent(Int.self, forKey: .uniqueCount) ?? 0,
            totalItems: try container.decodeIfPresent(Int.self, forKey: .totalItems) ?? 0,
            totalOpened: try container.decodeIfPresent(Int.self, forKey: .totalOpened) ?? 0,
            rebirthLevel: try container.decodeIfPresent(Int.self, forKey: .rebirthLevel) ?? 0,
            titleRank: try container.decodeIfPresent(Int.self, forKey: .titleRank) ?? 0,
            titleCount: try container.decodeIfPresent(Int.self, forKey: .titleCount) ?? 7,
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case progress
        case dust
        case title
        case nextTitle
        case uniqueCount
        case totalItems
        case totalOpened
        case rebirthLevel
        case titleRank
        case titleCount
        case updatedAt
    }
}

/// Accès au conteneur partagé entre l'application et ses extensions.
nonisolated enum ComplicationStore {
    /// Identifiant du groupe d'applications.
    static let suiteName = "group.com.minemaster.iut-st-die"

    /// Clé de l'état partagé.
    static let key = "complication.state"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Lit le dernier état partagé.
    ///
    /// - Returns: L'état validé, `nil` si le groupe ou la charge utile manque.
    static func load() -> ComplicationState? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(ComplicationState.self, from: data)
        } catch {
            return nil
        }
    }

    /// Écrit un état borné pour la complication.
    ///
    /// - Parameter state: État à partager.
    static func save(_ state: ComplicationState) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
        } catch {
            return
        }
    }

    /// Efface l'état partagé.
    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
