import Testing
@testable import MineMasterWatch

@MainActor
@Suite("Application Apple Watch")
struct WatchStoreTests {
    @Test("Le plan de pack prépare une ouverture de cinq cartes")
    func planProducesFiveCards() throws {
        let store = try #require(UITestSupport.makeStore())
        let plan = try #require(store.planOpening())

        let results = store.open(plan.booster, kind: plan.kind)

        #expect(results.count == 5)
        #expect(store.isOpening)
        #expect(store.open(plan.booster, kind: plan.kind).isEmpty)
    }

    @Test("Le catalogue de test de la montre contient six items")
    func fixturesExposeSixItems() throws {
        let store = try #require(UITestSupport.makeStore())

        #expect(store.catalog.count == 6)
        #expect(store.catalog.contains { $0.id == "diamond" })
        #expect(store.catalog.contains { $0.id == "nether_star" })
    }

    @Test("Une session terminée autorise l'ouverture suivante")
    func endOpeningUnlocksNextPack() throws {
        let store = try #require(UITestSupport.makeStore())
        let plan = try #require(store.planOpening())

        _ = store.open(plan.booster, kind: plan.kind)
        store.endOpening()
        let second = store.open(plan.booster, kind: plan.kind)

        #expect(second.count == 5)
        #expect(store.totalOpened == 2)
    }
}
