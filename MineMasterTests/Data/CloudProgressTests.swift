import Foundation
import SwiftData
import Testing
@testable import MineMaster

@MainActor
@Suite("Restauration distante")
struct CloudProgressTests {
    @Test("La progression distante remplace la collection locale")
    func appliesRemoteCollection() throws {
        let diamond = Fixtures.item("diamond", rarity: .rare)
        let dirt = Fixtures.item("dirt", rarity: .common)
        let fixture = try makeStore(items: [diamond, dirt], dust: 5)

        let applied = fixture.store.applyRemote(
            ProgressSnapshot(
                dust: 42,
                rebirthLevel: 2,
                marketPurchases: 3,
                marketSales: 4,
                owned: [diamond.id: 3],
                marketStock: [dirt.id: 0],
                updatedAt: .now
            )
        )

        #expect(applied)
        #expect(fixture.store.dust == 42)
        #expect(fixture.store.rebirthLevel == 2)
        #expect(fixture.store.marketPurchases == 3)
        #expect(fixture.store.ownedCount(for: diamond) == 3)
        #expect(fixture.store.ownedCount(for: dirt) == 0)
        #expect(fixture.store.marketOffer(for: dirt.id)?.stock == 0)
    }

    @Test("La progression distante ignore les identifiants hors catalogue")
    func ignoresUnknownIdentifiers() throws {
        let diamond = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [diamond], dust: 0)

        _ = fixture.store.applyRemote(
            ProgressSnapshot(
                dust: 10,
                rebirthLevel: 0,
                marketPurchases: 0,
                marketSales: 0,
                owned: ["ghost_item": 99],
                marketStock: ["ghost_item": 5],
                updatedAt: .now
            )
        )

        #expect(fixture.store.ownedCount(for: diamond) == 0)
        #expect(fixture.store.uniqueCount == 0)
        #expect(fixture.store.marketOffer(for: "ghost_item") == nil)
    }

    @Test("La progression restaurée survit à la réouverture du magasin")
    func persistsRestoredProgress() throws {
        let diamond = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [diamond], dust: 0)

        _ = fixture.store.applyRemote(
            ProgressSnapshot(
                dust: 17,
                rebirthLevel: 1,
                marketPurchases: 0,
                marketSales: 0,
                owned: [diamond.id: 2],
                marketStock: [diamond.id: 0],
                updatedAt: .now
            )
        )

        let reloaded = GameStore(container: fixture.container)

        #expect(reloaded.dust == 17)
        #expect(reloaded.rebirthLevel == 1)
        #expect(reloaded.ownedCount(for: diamond) == 2)
        #expect(reloaded.marketOffer(for: diamond.id)?.stock == 0)
    }

    @Test("L'export d'un instantané ne contient aucune entrée vide")
    func exportsOnlyOwnedEntries() throws {
        let diamond = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [diamond], dust: 8)

        let snapshot = fixture.store.progressSnapshot()

        #expect(snapshot.dust == 8)
        #expect(snapshot.owned.isEmpty)
        #expect(snapshot.marketStock[diamond.id] == 1)
    }

    @Test("Une restauration distante ne déclenche pas d'envoi vers le cloud")
    func restoringDoesNotMarkDirty() throws {
        let diamond = Fixtures.item("diamond", rarity: .rare)
        let fixture = try makeStore(items: [diamond], dust: 0)
        var persistCount = 0
        fixture.store.onPersist = { persistCount += 1 }

        _ = fixture.store.applyRemote(
            ProgressSnapshot(
                dust: 3,
                rebirthLevel: 0,
                marketPurchases: 0,
                marketSales: 0,
                owned: [diamond.id: 1],
                marketStock: [:],
                updatedAt: .now
            )
        )

        #expect(persistCount == 0)
    }
}
