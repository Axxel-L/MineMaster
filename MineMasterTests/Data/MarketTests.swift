import SwiftData
import Testing
@testable import MineMaster

@MainActor
@Suite("Marché")
struct MarketTests {
    @Test("Achat décrite la poussière, ajoute l'item et décrémente le stock")
    func buyDeductsDustAndAddsItem() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStoreWithMarket(items: [item], dust: 100)

        try fixture.store.buy(item)

        #expect(fixture.store.dust == 100 - MarketPrice.buy(for: .rare))
        #expect(fixture.store.ownedCount(for: item) == 1)
        #expect(fixture.store.marketPurchases == 1)
        #expect(fixture.store.marketOfferings.first { $0.item.id == item.id }?.stock == 0)
    }

    @Test("Achat avec poussière insuffisante échoue")
    func buyFailsWhenInsufficientDust() async throws {
        let item = Fixtures.item("diamond", rarity: .legendary)
        let fixture = try makeStoreWithMarket(items: [item], dust: 0)

        await expectAppError(.insufficientDust) {
            try fixture.store.buy(item)
        }

        #expect(fixture.store.dust == 0)
        #expect(fixture.store.ownedCount(for: item) == 0)
        #expect(fixture.store.marketPurchases == 0)
    }

    @Test("Achat sur stock nul échoue")
    func buyFailsWhenOutOfStock() async throws {
        let item = Fixtures.item("diamond", rarity: .common)
        let fixture = try makeStoreWithMarket(items: [item], dust: 100, stock: 0)

        await expectAppError(.outOfStock) {
            try fixture.store.buy(item)
        }

        #expect(fixture.store.dust == 100)
        #expect(fixture.store.ownedCount(for: item) == 0)
    }

    @Test("Vente crédite la poussière, retire l'item et réapprovisionne le stock")
    func sellCreditsDustAndRemovesItem() throws {
        let item = Fixtures.item("diamond", rarity: .epic)
        let fixture = try makeStoreWithMarket(
            items: [item],
            dust: 10,
            owned: [item.id: 2],
            stock: 0
        )

        try fixture.store.sell(item.id)

        #expect(fixture.store.dust == 10 + MarketPrice.sell(for: .epic))
        #expect(fixture.store.ownedCount(for: item) == 1)
        #expect(fixture.store.marketSales == 1)
        #expect(fixture.store.marketOfferings.first { $0.item.id == item.id }?.stock == 1)
    }

    @Test("Vendre le dernier exemplaire retire l'item des items uniques")
    func sellLastCopyClearsUnique() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStoreWithMarket(items: [item], dust: 0, owned: [item.id: 1])

        #expect(fixture.store.uniqueCount == 1)

        try fixture.store.sell(item.id)

        #expect(fixture.store.ownedCount(for: item) == 0)
        #expect(fixture.store.uniqueCount == 0)
        #expect(try count(CollectionRecord.self, in: fixture.container) == 0)
    }

    @Test("Vente d'un item non possédé échoue")
    func sellFailsWhenNotOwned() async throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStoreWithMarket(items: [item], dust: 0)

        await expectAppError(.notOwned) {
            try fixture.store.sell(item.id)
        }

        #expect(fixture.store.dust == 0)
        #expect(fixture.store.marketSales == 0)
    }

    @Test("Les prix de marché respectent l'étalement par rareté")
    func marketPricesScaleByRarity() throws {
        let items = Rarity.allCases.map { Fixtures.item("\($0.rawValue)_item", rarity: $0) }
        let fixture = try makeStoreWithMarket(items: items, dust: 0)

        let byRarity = Dictionary(uniqueKeysWithValues: fixture.store.marketOfferings.map {
            ($0.item.rarity, $0)
        })

        for rarity in Rarity.allCases {
            let offer = try #require(byRarity[rarity])
            #expect(offer.buyPrice == MarketPrice.buy(for: rarity))
            #expect(offer.sellPrice == MarketPrice.sell(for: rarity))
            #expect(offer.buyPrice == rarity.dustValue * 5)
            #expect(offer.sellPrice == rarity.dustValue)
            #expect(offer.buyPrice > offer.sellPrice)
        }
    }

    @Test("Les offres de marché sont triées par rareté")
    func marketOfferingsAreSortedByRarity() throws {
        let items = Rarity.allCases.reversed().map { Fixtures.item("\($0.rawValue)_item", rarity: $0) }
        let fixture = try makeStoreWithMarket(items: items, dust: 0)

        let ranks = fixture.store.marketOfferings.map { $0.item.rarity.rank }
        #expect(ranks == ranks.sorted())
    }

    @Test("Achats et ventes survivent au rechargement du magasin")
    func marketSurvivesReload() throws {
        let item = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStoreWithMarket(items: [item], dust: 100)

        try fixture.store.buy(item)

        let reloaded = GameStore(container: fixture.container)

        #expect(reloaded.ownedCount(for: item) == 1)
        #expect(reloaded.marketPurchases == 1)
    }

    private func makeStoreWithMarket(
        items: [CatalogItem] = [],
        dust: Int = 0,
        owned: [String: Int] = [:],
        stock: Int = 1
    ) throws -> StoreFixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CatalogItemRecord.self,
            CollectionRecord.self,
            PlayerRecord.self,
            OpeningRecord.self,
            MarketListingRecord.self,
            configurations: configuration
        )
        let context = container.mainContext

        for item in items {
            context.insert(CatalogItemRecord(item: item))
            context.insert(MarketListingRecord(itemID: item.id, stock: stock))
        }
        if dust > 0 {
            let player = PlayerRecord()
            player.dust = dust
            context.insert(player)
        }
        for (itemID, quantity) in owned {
            let record = CollectionRecord(itemID: itemID)
            record.quantity = quantity
            context.insert(record)
        }
        try context.save()

        return StoreFixture(
            store: GameStore(container: container),
            container: container
        )
    }

    private func count<T: PersistentModel>(
        _ type: T.Type,
        in container: ModelContainer
    ) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }
}
