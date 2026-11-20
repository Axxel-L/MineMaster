import SwiftData
import Testing
@testable import MineMaster

@MainActor
@Suite("Renaissance")
struct RebirthTests {
    @Test("La renaissance est verrouillée sous le seuil d'items")
    func rebirthLockedBelowThreshold() async throws {
        let items = Fixtures.items(10)
        let fixture = try makeStore(items: items, draw: { _, pool, _ in pool })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()

        #expect(!fixture.store.canRebirth)
        await expectAppError(.rebirthLocked) {
            try fixture.store.rebirth()
        }
        #expect(fixture.store.rebirthLevel == 0)
    }

    @Test("La renaissance vide la collection et la poussière, garde les ouvertures")
    func rebirthResetsCollectionAndDust() throws {
        let items = Fixtures.items(30)
        let fixture = try makeStore(items: items, dust: 500, draw: { _, pool, _ in pool })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        #expect(fixture.store.uniqueCount == 30)

        try fixture.store.rebirth()

        #expect(fixture.store.uniqueCount == 0)
        #expect(fixture.store.dust == 0)
        #expect(fixture.store.rebirthLevel == 1)
        #expect(fixture.store.totalOpened == 1)
        #expect(fixture.store.canRebirth == false)
    }

    @Test("La renaissance est persistée au rechargement")
    func rebirthSurvivesReload() throws {
        let items = Fixtures.items(30)
        let fixture = try makeStore(items: items, dust: 0, draw: { _, pool, _ in pool })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        try fixture.store.rebirth()

        let reloaded = GameStore(container: fixture.container)
        #expect(reloaded.rebirthLevel == 1)
        #expect(reloaded.uniqueCount == 0)
    }

    @Test("La renaissance réapprovisionne le stock du marché à 1")
    func rebirthResetsMarketStock() throws {
        let items = Fixtures.items(30)
        let fixture = try makeStore(items: items, dust: 500, draw: { _, pool, _ in pool })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        try fixture.store.buy(items[0])
        #expect(fixture.store.marketOffer(for: items[0].id)?.stock == 0)

        try fixture.store.rebirth()

        #expect(fixture.store.marketOffer(for: items[0].id)?.stock == 1)
    }

    @Test("Les boosts de rareté et de poussière augmentent par palier")
    func boostScalesWithLevel() {
        let zero = RebirthBoost.none
        let two = RebirthBoost(level: 2)

        #expect(zero.weightMultiplier(for: .legendary) == 1)
        #expect(two.weightMultiplier(for: .legendary) == 1 + 2 * RebirthBoost.legendaryStep)
        #expect(two.weightMultiplier(for: .epic) == 1 + 2 * RebirthBoost.epicStep)
        #expect(two.weightMultiplier(for: .common) == 1)
        #expect(two.dust(for: .legendary) == Int((50 * (1 + 2 * RebirthBoost.dustStep)).rounded()))
        #expect(zero.dust(for: .rare) == Rarity.rare.dustValue)
    }

    @Test("Le boost de renaissance est transmis au tirage")
    func boostReachesDrawProvider() throws {
        let items = Fixtures.items(30)
        let box = BoostProbe()
        let fixture = try makeStore(items: items, draw: { _, pool, boost in
            box.value = boost
            return pool
        })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        #expect(box.value == .none)

        try fixture.store.rebirth()
        _ = fixture.store.open(.common)

        #expect(box.value.level == 1)
    }

    @Test("Le boost de poussière s'applique aux doublons")
    func dustBoostAppliesToDuplicates() throws {
        var items = Fixtures.items(30)
        let legendary = Fixtures.item("legendary_token", rarity: .legendary)
        items.append(legendary)

        let draw = DrawBox()
        let fixture = try makeStore(items: items, draw: { _, _, _ in draw.next })

        draw.next = items
        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        #expect(fixture.store.canRebirth)

        try fixture.store.rebirth()

        draw.next = [legendary, legendary]
        let results = fixture.store.open(.common)

        #expect(results.count == 2)
        #expect(results[0].isNew)
        #expect(results[1].isNew == false)
        #expect(results[1].dust == RebirthBoost(level: 1).dust(for: .legendary))
        #expect(fixture.store.dust == RebirthBoost(level: 1).dust(for: .legendary))
    }
}

@MainActor
private final class BoostProbe {
    var value = RebirthBoost.none
}

@MainActor
private final class DrawBox {
    var next: [CatalogItem] = []
}
