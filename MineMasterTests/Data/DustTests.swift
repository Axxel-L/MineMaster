import Testing
@testable import MineMaster

@MainActor
@Suite("Poussière distribuée à l'ouverture")
struct DustTests {
    @Test("Un item nouveau rapporte 0 poussière")
    func nouveauRapporteZero() throws {
        let fixture = try makeStore(items: Fixtures.items(5), draw: { _, pool in pool })

        let results = fixture.store.open(.common)

        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.isNew })
        #expect(results.allSatisfy { $0.dust == 0 })
        #expect(fixture.store.dust == 0)
    }

    @Test("Chaque doublon rapporte exactement la valeur de sa rareté")
    func doublonRapporteSaValeur() throws {
        let items = [
            Fixtures.item("dirt", rarity: .common, category: .block),
            Fixtures.item("stick", rarity: .common),
            Fixtures.item("iron_ingot", rarity: .uncommon),
            Fixtures.item("diamond", rarity: .rare),
            Fixtures.item("nether_star", rarity: .legendary)
        ]
        let fixture = try makeStore(items: items, draw: { _, pool in pool })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        let results = fixture.store.open(.common)

        #expect(results.count == 5)
        #expect(results.allSatisfy { !$0.isNew })
        #expect(results.allSatisfy { $0.dust == $0.item.rarity.dustValue })
        #expect(fixture.store.dust == items.reduce(0) { $0 + $1.rarity.dustValue })
    }

    @Test("La poussière du magasin égale celle des doublons du paquet")
    func totalCoherentAvecLaCollection() throws {
        var calls = 0
        let fixture = try makeStore(items: Fixtures.items(5), draw: { _, pool in
            calls += 1
            return calls == 1 ? Array(pool.prefix(2)) : pool
        })

        let first = fixture.store.open(.common)
        fixture.store.endOpening()
        let results = fixture.store.open(.common)
        let ownedIDs = Set(first.map(\.item.id))
        let expected = results
            .filter { ownedIDs.contains($0.item.id) }
            .reduce(0) { $0 + $1.item.rarity.dustValue }

        #expect(results.allSatisfy { $0.isNew == !ownedIDs.contains($0.item.id) })
        #expect(results.reduce(0) { $0 + $1.dust } == expected)
        #expect(fixture.store.dust == expected)
    }

    @Test("La poussière se cumule d'une ouverture à l'autre")
    func cumulEntreOuvertures() throws {
        let items = Fixtures.items(5, rarity: .uncommon)
        let fixture = try makeStore(items: items, dust: 10, draw: { _, pool in pool })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        let second = fixture.store.open(.common)

        #expect(second.allSatisfy { !$0.isNew })
        #expect(fixture.store.dust == 10 + items.count * Rarity.uncommon.dustValue)
    }
}
