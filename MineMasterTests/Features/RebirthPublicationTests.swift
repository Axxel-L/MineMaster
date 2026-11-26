import Testing
@testable import MineMaster

@MainActor
@Suite("Publication après renaissance")
struct RebirthPublicationTests {
    @Test("Une renaissance publie une collection déjà vidée")
    func rebirthPublishesClearedCollection() throws {
        let items = Fixtures.items(Rebirth.minimumUniqueItems)
        let fixture = try makeStore(
            items: items,
            draw: { _, _, _ in items }
        )
        _ = fixture.store.open(.common)

        var published: ComplicationState?
        fixture.store.onPersist = {
            published = WidgetStatePublisher.makeState(from: fixture.store)
        }

        try fixture.store.rebirth()

        #expect(published?.uniqueCount == 0)
        #expect(published?.dust == 0)
        #expect(published?.rebirthLevel == 1)
        #expect(published?.totalOpened == 1)
    }
}
