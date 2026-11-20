import Foundation

/// Représentation de domaine d'une offre de marché.
///
/// Le stock est persisté ; les prix sont recalculés depuis la rareté de l'item.
///
/// - Authors: Axel L.
struct MarketOffer: Identifiable, Hashable, Sendable {
    let item: CatalogItem
    let stock: Int

    var id: String { item.id }

    /// Prix d'achat en poussière.
    var buyPrice: Int { MarketPrice.buy(for: item.rarity) }

    /// Prix de revente en poussière.
    var sellPrice: Int { MarketPrice.sell(for: item.rarity) }
}

/// Prix du marché, dérivés de la rareté.
///
/// Achat = `dustValue × 5`, revente = `dustValue` (spread 5:1).
///
/// - Authors: Axel L.
enum MarketPrice {
    /// Prix d'achat en poussière pour un item de cette rareté.
    ///
    /// - Parameter rarity: Rareté évaluée.
    /// - Returns: Prix d'achat, toujours strictement positif.
    /// - Authors: Axel L.
    static func buy(for rarity: Rarity) -> Int {
        rarity.dustValue * 5
    }

    /// Prix de revente en poussière pour un item de cette rareté.
    ///
    /// - Parameter rarity: Rareté évaluée.
    /// - Returns: Prix de revente, identique à la valeur d'un doublon.
    /// - Authors: Axel L.
    static func sell(for rarity: Rarity) -> Int {
        rarity.dustValue
    }
}
