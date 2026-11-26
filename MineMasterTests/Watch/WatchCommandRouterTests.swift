import Foundation
import SwiftData
import Testing
@testable import MineMaster

@MainActor
@Suite("Commandes de la montre")
struct WatchCommandRouterTests {
    private func makeStats(
        pulls: Int = 0,
        trades: Int = 0
    ) -> GlobalStatsSync {
        GlobalStatsSync(
            transport: .init(
                fetch: {
                    [
                        "test_1": GlobalItemStats(pulls: pulls, marketTrades: trades, updatedAt: .now)
                    ]
                },
                push: { _ in }
            )
        )
    }

    @Test("Un plan ne consomme pas le verrou et n'enregistre rien")
    func planDoesNotLock() async throws {
        let fixture = try makeStore(items: Fixtures.items(10))
        let router = WatchCommandRouter(store: fixture.store, stats: makeStats())

        let reply = await router.handle(WatchCommand(action: .plan))

        #expect(reply.kind == .plan)
        #expect(reply.plan?.booster == .common)
        #expect(reply.plan?.kind == .mixed)
        #expect(!fixture.store.isOpening)
        #expect(fixture.store.totalOpened == 0)
    }

    @Test("Une ouverture renvoie cinq cartes et une commande rejouée ne double rien")
    func openIsIdempotent() async throws {
        let fixture = try makeStore(
            items: Fixtures.items(10),
            draw: { _, pool, _ in Array(pool.prefix(5)) }
        )
        let router = WatchCommandRouter(store: fixture.store, stats: makeStats())
        let planReply = await router.handle(WatchCommand(action: .plan))
        let plan = try #require(planReply.plan)
        let command = WatchCommand(
            action: .open,
            booster: try #require(plan.booster),
            kind: try #require(plan.kind)
        )

        let first = await router.handle(command)
        let second = await router.handle(command)
        let opened = try #require(first.opened)

        #expect(first.kind == .opened)
        #expect(opened.cards.count == 5)
        #expect(opened.state.totalOpened == 1)
        #expect(second == first)
        #expect(fixture.store.totalOpened == 1)
        #expect(fixture.store.owned.values.reduce(0, +) == 5)
    }

    @Test("La fermeture d'une session autorise l'ouverture suivante")
    func closeUnlocks() async throws {
        let fixture = try makeStore(
            items: Fixtures.items(10),
            draw: { _, pool, _ in Array(pool.prefix(5)) }
        )
        let router = WatchCommandRouter(store: fixture.store, stats: makeStats())
        let planReply = await router.handle(WatchCommand(action: .plan))
        let plan = try #require(planReply.plan)
        let open = WatchCommand(
            action: .open,
            booster: try #require(plan.booster),
            kind: try #require(plan.kind)
        )

        _ = await router.handle(open)
        _ = await router.handle(WatchCommand(action: .close))
        let next = await router.handle(
            WatchCommand(
                action: .open,
                booster: try #require(plan.booster),
                kind: try #require(plan.kind)
            )
        )

        #expect(next.kind == .opened)
        #expect(fixture.store.totalOpened == 2)
    }

    @Test("Un achat débite la poussière, une vente la crédite")
    func marketTrades() async throws {
        let item = Fixtures.item("dirt")
        let fixture = try makeStore(items: [item], dust: 100)
        let router = WatchCommandRouter(store: fixture.store, stats: makeStats())
        let buyPrice = MarketPrice.buy(for: item.rarity)

        let bought = await router.handle(WatchCommand(action: .buy, itemID: item.id))
        let sold = await router.handle(WatchCommand(action: .sell, itemID: item.id))

        #expect(bought.kind == .state)
        #expect(sold.kind == .state)
        #expect(fixture.store.ownedCount(for: item) == 0)
        #expect(fixture.store.dust == 100 - buyPrice + MarketPrice.sell(for: item.rarity))
        #expect(fixture.store.marketPurchases == 1)
        #expect(fixture.store.marketSales == 1)
    }

    @Test("Un stock épuisé et un identifiant invalide sont refusés")
    func refusesInvalidTrade() async throws {
        let item = Fixtures.item("dirt")
        let fixture = try makeStore(items: [item], dust: 1_000)
        let router = WatchCommandRouter(store: fixture.store, stats: makeStats())

        _ = await router.handle(WatchCommand(action: .buy, itemID: item.id))
        let outOfStock = await router.handle(WatchCommand(action: .buy, itemID: item.id))
        let invalid = await router.handle(WatchCommand(action: .buy, itemID: "../secret"))

        #expect(outOfStock.kind == .failure)
        #expect(invalid.kind == .failure)
        #expect(fixture.store.dust == 1_000 - MarketPrice.buy(for: item.rarity))
    }

    @Test("Les agrégats communautaires sont transmis avec l'état")
    func communityTotals() async throws {
        let fixture = try makeStore(items: Fixtures.items(2))
        let stats = makeStats(pulls: 12, trades: 4)
        let router = WatchCommandRouter(store: fixture.store, stats: stats)

        let refreshed = await router.handle(WatchCommand(action: .refreshStats))
        let item = await router.handle(WatchCommand(action: .item, itemID: "test_1"))

        #expect(refreshed.state?.globalPulls == 12)
        #expect(refreshed.state?.globalTrades == 4)
        #expect(item.item?.globalPulls == 12)
        #expect(item.item?.globalTrades == 4)
    }

    @Test("La montre reçoit le catalogue embarqué sans réseau")
    func bootstrapLoadsBundledCatalog() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GameContainer.schema,
            configurations: [configuration]
        )
        let store = GameStore(container: container, syncOnBootstrap: false)

        await store.bootstrap()

        #expect(store.isBootstrapped)
        #expect(store.catalog.count == 515)
        #expect(store.marketOfferings.count == 515)
        #expect(store.loadError == nil)
    }
}
