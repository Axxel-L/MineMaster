import Testing
@testable import MineMaster

@MainActor
@Suite("Ouverture d'un seul booster à la fois")
struct OpeningLockTests {
    @Test("Quatre appuis rapides produisent une seule ouverture de cinq cartes")
    func appuisRapides() throws {
        let fixture = try makeStore(items: Fixtures.items(5), draw: { _, pool in pool })

        let attempts = (0..<4).map { _ in fixture.store.open(.common) }

        #expect(attempts[0].count == 5)
        #expect(attempts.dropFirst().allSatisfy { $0.isEmpty })
        #expect(fixture.store.isOpening)
        #expect(fixture.store.totalOpened == 1)
        #expect(fixture.store.owned.values.reduce(0, +) == 5)
    }

    @Test("Tant que la session n'est pas fermée, aucun autre booster ne s'ouvre")
    func refusePendantLaSession() throws {
        let fixture = try makeStore(items: Fixtures.items(5), draw: { _, pool in pool })

        let first = fixture.store.open(.common)
        let dustAfterFirst = fixture.store.dust
        let other = fixture.store.open(.legendary)

        #expect(!first.isEmpty)
        #expect(other.isEmpty)
        #expect(fixture.store.isOpening)
        #expect(fixture.store.totalOpened == 1)
        #expect(fixture.store.dust == dustAfterFirst)
    }

    @Test("Après la fermeture de la session, l'ouverture suivante réussit")
    func reussitApresFermeture() throws {
        let fixture = try makeStore(items: Fixtures.items(10), draw: { _, pool in Array(pool.prefix(5)) })

        _ = fixture.store.open(.common)
        fixture.store.endOpening()
        let next = fixture.store.open(.rare)

        #expect(next.count == 5)
        #expect(fixture.store.isOpening)
        #expect(fixture.store.totalOpened == 2)
    }

    @Test("Un catalogue vide ne verrouille pas l'ouverture")
    func catalogueVideSansVerrou() throws {
        let fixture = try makeStore(items: [])

        let results = fixture.store.open(.common)

        #expect(results.isEmpty)
        #expect(!fixture.store.isOpening)
        #expect(fixture.store.totalOpened == 0)
    }
}
