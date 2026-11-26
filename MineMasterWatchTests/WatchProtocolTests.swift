import Foundation
import Testing
@testable import MineMasterWatch

@MainActor
@Suite("Protocole de la montre")
struct WatchProtocolTests {
    @Test("Un paquet d'état fait l'aller-retour sans perte")
    func stateRoundTrip() throws {
        let snapshot = ProgressSnapshot(
            dust: 12,
            rebirthLevel: 1,
            marketPurchases: 2,
            marketSales: 3,
            owned: ["diamond": 2, "dirt": 1],
            marketStock: ["diamond": 1],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let state = WatchState(
            snapshot: snapshot,
            totalOpened: 4,
            globalPulls: 5,
            globalTrades: 6,
            globalLoaded: true
        )

        let data = try #require(WatchWire.encode(.state(state)))
        let packet = try #require(WatchWire.decode(data))

        #expect(packet.kind == .state)
        #expect(packet.state == state)
    }

    @Test("Une charge utile trop grande ou invalide est refusée")
    func rejectsInvalidPayload() throws {
        let oversized = Data(repeating: 1, count: WatchWire.maximumBytes + 1)
        let invalidCommand = WatchCommand(action: .buy, itemID: "../secret")
        let invalidData = try #require(WatchWire.encode(.command(invalidCommand)))

        #expect(WatchWire.decode(oversized) == nil)
        #expect(WatchWire.decode(invalidData) == nil)
    }

    @Test("Un instantané reçu est borné avant d'atteindre la montre")
    func clampsDecodedSnapshot() throws {
        let json = """
        {"dust":-5,"rebirthLevel":-1,"marketPurchases":-1,"marketSales":-1,
        "owned":{"diamond":-2,"bad/id":3,"dirt":999999},
        "marketStock":{"dirt":-1},"updatedAt":0}
        """
        let snapshot = try JSONDecoder().decode(ProgressSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.dust == 0)
        #expect(snapshot.rebirthLevel == 0)
        #expect(snapshot.owned["diamond"] == nil)
        #expect(snapshot.owned["bad/id"] == nil)
        #expect(snapshot.owned["dirt"] == ProgressSnapshot.maximumQuantity)
        #expect(snapshot.marketStock.isEmpty)
    }

    @Test("Les compteurs d'état sont bornés à la construction")
    func clampsStateCounters() {
        let state = WatchState(
            snapshot: .empty(),
            totalOpened: -5,
            globalPulls: Int.max,
            globalTrades: -1,
            globalLoaded: true
        )

        #expect(state.totalOpened == 0)
        #expect(state.globalPulls == ProgressSnapshot.maximumCounter)
        #expect(state.globalTrades == 0)
    }

    @Test("La complication borne sa jauge, sa poussière et son titre")
    func clampsComplication() {
        let state = ComplicationState(
            progress: 2,
            dust: -3,
            title: String(repeating: "a", count: 80),
            nextTitle: String(repeating: "b", count: 80),
            updatedAt: .now
        )

        #expect(state.progress == 1)
        #expect(state.dust == 0)
        #expect(state.title.count == 40)
        #expect(state.nextTitle?.count == 40)
    }

    @Test("Un lien local prépare puis ouvre cinq cartes")
    func localLinkOpensFiveCards() async throws {
        let store = try #require(UITestSupport.makeStore())
        let link = WatchLink(store: store, mode: .local)
        let plan = try #require(await link.plan())

        let opened = try #require(await link.open(plan))

        #expect(opened.cards.count == 5)
        #expect(link.totalOpened == 1)
        link.closeOpening()
        let again = try #require(await link.plan())
        let second = try #require(await link.open(again))
        #expect(second.cards.count == 5)
    }

    @Test("Un lien local expose les tirages de l'item")
    func localLinkExposesItemStats() async throws {
        let store = try #require(UITestSupport.makeStore())
        let link = WatchLink(store: store, mode: .local)
        let plan = try #require(await link.plan())
        _ = try #require(await link.open(plan))

        let stats = try #require(await link.itemStats("diamond"))

        #expect(stats.localPulls == 1)
        #expect(stats.globalPulls == 0)
    }
}
