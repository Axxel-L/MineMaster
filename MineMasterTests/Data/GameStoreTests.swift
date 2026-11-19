import SwiftData
import Testing
@testable import MineMaster

@MainActor
@Suite("Magasin de jeu")
struct GameStoreTests {
    @Test("Quatre appuis sur Ouvrir produisent une seule ouverture")
    func fourTapsProduceOneOpening() throws {
        let item = Fixtures.item("oak_log", category: .block)
        let fixture = try makeStore(items: [item], draw: { _, _ in [item] })

        #expect(fixture.store.open(.common).count == 1)
        for _ in 0..<3 {
            #expect(fixture.store.open(.rare).isEmpty)
        }

        #expect(fixture.store.isOpening)
        #expect(try count(OpeningRecord.self, in: fixture.container) == 1)

        fixture.store.endOpening()
        #expect(fixture.store.open(.common).count == 1)
        #expect(try count(OpeningRecord.self, in: fixture.container) == 2)
    }

    @Test("Un item nouveau ne rapporte aucune poussière")
    func newItemGivesNoDust() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [item], draw: { _, _ in [item] })

        let result = fixture.store.open(.rare)

        #expect(result.first?.isNew == true)
        #expect(result.first?.dust == 0)
        #expect(fixture.store.dust == 0)
    }

    @Test("Un doublon rapporte exactement la poussière de sa rareté")
    func duplicateGivesExactDust() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [item], draw: { _, _ in [item] })

        _ = fixture.store.open(.rare)
        fixture.store.endOpening()
        let result = fixture.store.open(.rare)

        #expect(result.first?.isNew == false)
        #expect(result.first?.dust == Rarity.rare.dustValue)
        #expect(fixture.store.dust == Rarity.rare.dustValue)
    }

    @Test("Plusieurs doublons dans un même tirage cumulent leur poussière")
    func multipleDuplicatesAccumulateDust() throws {
        let item = Fixtures.item("nether_star", rarity: .legendary)
        let fixture = try makeStore(
            items: [item],
            draw: { _, _ in [item, item, item] }
        )

        let result = fixture.store.open(.legendary)

        #expect(result.count == 3)
        #expect(result[0].dust == 0)
        #expect(result[1].dust == Rarity.legendary.dustValue)
        #expect(result[2].dust == Rarity.legendary.dustValue)
        #expect(fixture.store.dust == Rarity.legendary.dustValue * 2)
        #expect(fixture.store.ownedCount(for: item) == 3)
        #expect(try count(CollectionRecord.self, in: fixture.container) == 1)
    }

    @Test("Un pack aléatoire respecte le type tiré")
    func randomPackFiltersKind() throws {
        let panda = Fixtures.item("panda", rarity: .rare, category: .mob)
        let diamond = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(
            items: [panda, diamond],
            draw: { _, items in items },
            boosterProvider: { _ in (.rare, .creatures) }
        )

        let open = try #require(fixture.store.openRandom())

        #expect(open.kind == .creatures)
        #expect(open.results.count == 1)
        #expect(open.results.allSatisfy { $0.item.category == .mob })
    }

    @Test("Les tirages locaux sont comptés par item")
    func localPullCountIsTracked() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [item], draw: { _, _ in [item] })

        _ = fixture.store.open(.rare)
        fixture.store.endOpening()
        _ = fixture.store.open(.rare)

        #expect(fixture.store.pullCount(for: item) == 2)
    }

    @Test("Les items possédés restent récupérables après rechargement")
    func ownedItemsSurviveReload() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(
            items: [item],
            dust: 100,
            draw: { _, _ in [item] }
        )

        _ = fixture.store.open(.rare)
        let reloaded = GameStore(container: fixture.container)

        #expect(reloaded.ownedCount(for: item) == 1)
        #expect(try count(CollectionRecord.self, in: fixture.container) == 1)
    }

    private func count<T: PersistentModel>(
        _ type: T.Type,
        in container: ModelContainer
    ) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }
}
