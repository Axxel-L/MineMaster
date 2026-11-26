import Foundation

/// Progression d'un compte, sérialisable vers Firestore.
///
/// Seules les valeurs métier sont transportées. Les prix, les titres et les
/// rendus visuels sont recalculés localement depuis le catalogue, donc jamais
/// falsifiables par un document distant.
nonisolated struct ProgressSnapshot: Sendable, Equatable {
    /// Plafond appliqué à toute quantité reçue du réseau.
    static let maximumQuantity = 9_999

    /// Plafond appliqué au nombre d'entrées d'une carte distante.
    static let maximumEntries = 2_000

    /// Plafond de la poussière et des compteurs de marché.
    ///
    /// Aligné sur la borne des règles Firestore : une valeur plus grande ferait
    /// rejeter chaque écriture du compte.
    static let maximumCounter = 1_000_000_000

    /// Plafond du niveau de renaissance, aligné sur les règles Firestore.
    static let maximumRebirthLevel = 1_000

    /// Poussière du joueur.
    let dust: Int
    /// Paliers de renaissance acquis.
    let rebirthLevel: Int
    /// Nombre total d'achats au marché.
    let marketPurchases: Int
    /// Nombre total de ventes au marché.
    let marketSales: Int
    /// Quantité possédée par identifiant d'item.
    let owned: [String: Int]
    /// Stock du marché par identifiant d'item.
    let marketStock: [String: Int]
    /// Date de la dernière écriture connue.
    let updatedAt: Date

    /// Construit un instantané en bornant toutes les valeurs.
    ///
    /// Chaque borne correspond à la règle Firestore correspondante, pour qu'un
    /// instantané local ne puisse jamais être refusé à l'écriture.
    ///
    /// - Parameters:
    ///   - dust: Poussière, comprise entre `0` et `maximumCounter`.
    ///   - rebirthLevel: Paliers de renaissance, compris entre `0` et `maximumRebirthLevel`.
    ///   - marketPurchases: Achats cumulés, compris entre `0` et `maximumCounter`.
    ///   - marketSales: Ventes cumulées, comprises entre `0` et `maximumCounter`.
    ///   - owned: Quantités possédées, entrées nulles ou invalides retirées.
    ///   - marketStock: Stocks du marché, entrées invalides retirées.
    ///   - updatedAt: Date de référence de l'instantané.
    init(
        dust: Int,
        rebirthLevel: Int,
        marketPurchases: Int,
        marketSales: Int,
        owned: [String: Int],
        marketStock: [String: Int],
        updatedAt: Date
    ) {
        self.dust = Self.clamp(dust, maximum: Self.maximumCounter)
        self.rebirthLevel = Self.clamp(rebirthLevel, maximum: Self.maximumRebirthLevel)
        self.marketPurchases = Self.clamp(marketPurchases, maximum: Self.maximumCounter)
        self.marketSales = Self.clamp(marketSales, maximum: Self.maximumCounter)
        self.owned = Self.sanitize(owned)
        self.marketStock = Self.sanitize(marketStock, minimum: 0)
        self.updatedAt = updatedAt
    }

    /// Ramène une valeur dans l'intervalle accepté par les règles distantes.
    ///
    /// - Parameters:
    ///   - value: Valeur brute.
    ///   - maximum: Borne haute incluse.
    /// - Returns: La valeur bornée.
    static func clamp(_ value: Int, maximum: Int) -> Int {
        min(max(value, 0), maximum)
    }

    /// Instantané vide, utilisé pour un compte qui n'a jamais joué.
    ///
    /// - Parameter updatedAt: Date de référence.
    /// - Returns: Un instantané sans progression.
    static func empty(updatedAt: Date = .now) -> ProgressSnapshot {
        ProgressSnapshot(
            dust: 0,
            rebirthLevel: 0,
            marketPurchases: 0,
            marketSales: 0,
            owned: [:],
            marketStock: [:],
            updatedAt: updatedAt
        )
    }

    /// Filtre et borne une carte de quantités.
    ///
    /// - Parameters:
    ///   - values: Carte brute.
    ///   - minimum: Valeur minimale conservée. Les stocks acceptent `0`, une
    ///     offre épuisée restant une information utile.
    /// - Returns: Carte sans entrée invalide ou surnuméraire.
    static func sanitize(_ values: [String: Int], minimum: Int = 1) -> [String: Int] {
        var result: [String: Int] = [:]
        result.reserveCapacity(min(values.count, maximumEntries))
        for (key, value) in values where isSafeIdentifier(key) && value >= minimum {
            guard result.count < maximumEntries else { break }
            result[key] = min(value, maximumQuantity)
        }
        return result
    }

    /// Valide un identifiant d'item reçu du réseau.
    ///
    /// - Parameter identifier: Identifiant à valider.
    /// - Returns: `true` si l'identifiant respecte le format du catalogue.
    static func isSafeIdentifier(_ identifier: String) -> Bool {
        guard (1...64).contains(identifier.count) else { return false }
        return identifier.allSatisfy { character in
            character.isASCII && (character.isLowercase || character.isNumber || character == "_")
        }
    }
}
