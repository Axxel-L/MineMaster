import Foundation

/// Boosts permanents accordés par les renaissances.
///
/// Chaque palier augmente les chances d'obtenir des items épiques et
/// légendaires, ainsi que la poussière gagnée sur les doublons. Les boosts se
/// cumulent sans plafond.
struct RebirthBoost: Sendable, Equatable {
    /// Nombre de renaissances déjà effectuées.
    let level: Int

    /// Aucun boost, pour un joueur sans renaissance.
    static let none = RebirthBoost(level: 0)

    /// Gain de poids par palier pour la rareté épique.
    static let epicStep = 0.10

    /// Gain de poids par palier pour la rareté légendaire.
    static let legendaryStep = 0.15

    /// Gain de poussière par palier.
    static let dustStep = 0.10

    /// Bonus cumulé appliqué aux items épiques, `0.10` par palier.
    var epicBonus: Double { Self.epicStep * Double(level) }

    /// Bonus cumulé appliqué aux items légendaires, `0.15` par palier.
    var legendaryBonus: Double { Self.legendaryStep * Double(level) }

    /// Bonus cumulé appliqué à la poussière, `0.10` par palier.
    var dustBonus: Double { Self.dustStep * Double(level) }

    /// Multiplicateur de poids appliqué à une rareté lors du tirage.
    ///
    /// - Parameter rarity: Rareté évaluée.
    /// - Returns: `1` hors épique et légendaire, sinon le bonus cumulé
    ///   correspondant.
    func weightMultiplier(for rarity: Rarity) -> Double {
        switch rarity {
        case .epic: 1 + epicBonus
        case .legendary: 1 + legendaryBonus
        default: 1
        }
    }

    /// Poussière gagnée pour un doublon de cette rareté.
    ///
    /// - Parameter rarity: Rareté du doublon.
    /// - Returns: La valeur de base augmentée du bonus, arrondie à l'entier.
    /// - Complexity: O(1).
    func dust(for rarity: Rarity) -> Int {
        Int((Double(rarity.dustValue) * (1 + dustBonus)).rounded())
    }
}

/// Règles de déblocage des renaissances.
enum Rebirth {
    /// Nombre d'items différents requis pour pouvoir renaître.
    static let minimumUniqueItems = 25

    /// Progression vers la prochaine renaissance, entre `0` et `1`.
    ///
    /// - Parameter uniqueCount: Nombre d'items différents possédés.
    /// - Returns: La progression bornée, `1` dès que le seuil est atteint.
    static func progress(uniqueCount: Int) -> Double {
        guard minimumUniqueItems > 0 else { return 1 }
        return min(max(Double(uniqueCount) / Double(minimumUniqueItems), 0), 1)
    }

    /// Nombre d'items encore manquants avant de pouvoir renaître.
    ///
    /// - Parameter uniqueCount: Nombre d'items différents possédés.
    /// - Returns: Le reste à obtenir, borné à `0`.
    static func remaining(uniqueCount: Int) -> Int {
        max(minimumUniqueItems - uniqueCount, 0)
    }
}
