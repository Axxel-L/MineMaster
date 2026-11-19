import Foundation

/// Moteur de tirage des boosters.
///
/// Les probabilités sont pondérées par rareté puis ajustées par le multiplicateur du booster.
/// Aucun item ne peut apparaître deux fois dans un même paquet.
///
/// - Authors: Axel L.
struct LootEngine: Sendable {

    /// Tire les cartes d'un booster.
    ///
    /// - Parameters:
    ///   - items: Catalogue disponible.
    ///   - booster: Configuration du booster ouvert.
    ///   - generator: Générateur aléatoire injecté pour la reproductibilité.
    /// - Returns: Les items tirés, dans l'ordre de révélation, sans doublon.
    /// - Complexity: O(n × k) où *n* est la taille du catalogue et *k* le nombre de cartes.
    /// - Authors: Axel L.
    func draw<G: RandomNumberGenerator>(
        from items: [CatalogItem],
        booster: Booster,
        using generator: inout G
    ) -> [CatalogItem] {
        guard !items.isEmpty else { return [] }

        var pool = items
        var result: [CatalogItem] = []

        if let guarantee = booster.guarantee {
            let guaranteed = pool.filter { $0.rarity >= guarantee }
            if let pick = pick(from: guaranteed, booster: booster, using: &generator) {
                result.append(pick)
                pool.removeAll { $0.id == pick.id }
            }
        }

        while result.count < booster.cardCount, !pool.isEmpty {
            guard let pick = pick(from: pool, booster: booster, using: &generator) else { break }
            result.append(pick)
            pool.removeAll { $0.id == pick.id }
        }

        return result
    }

    private func weight(of item: CatalogItem, booster: Booster) -> Double {
        item.rarity.baseWeight * booster.multiplier(for: item.rarity)
    }

    private func pick<G: RandomNumberGenerator>(
        from pool: [CatalogItem],
        booster: Booster,
        using generator: inout G
    ) -> CatalogItem? {
        let weighted = pool.map { ($0, weight(of: $0, booster: booster)) }
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }

        var roll = Double.random(in: 0..<total, using: &generator)
        for (item, weight) in weighted {
            if weight <= 0 { continue }
            if roll < weight { return item }
            roll -= weight
        }
        return weighted.last(where: { $0.1 > 0 })?.0
    }
}
