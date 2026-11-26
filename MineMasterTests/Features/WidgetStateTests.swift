import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("État des widgets iPhone")
struct WidgetStateTests {
    @Test("Les compteurs partagés sont bornés à la construction")
    func clampsSharedCounters() {
        let state = ComplicationState(
            progress: 4,
            dust: -5,
            title: String(repeating: "a", count: 80),
            nextTitle: String(repeating: "b", count: 80),
            uniqueCount: 999,
            totalItems: 5,
            totalOpened: -3,
            rebirthLevel: Int.max,
            titleRank: 99,
            titleCount: 3,
            updatedAt: .now
        )

        #expect(state.progress == 1)
        #expect(state.dust == 0)
        #expect(state.title.count == 40)
        #expect(state.nextTitle?.count == 40)
        #expect(state.totalItems == 5)
        #expect(state.uniqueCount == 5)
        #expect(state.totalOpened == 0)
        #expect(state.rebirthLevel == ComplicationState.maximumRebirthLevel)
        #expect(state.titleCount == 3)
        #expect(state.titleRank == 2)
    }

    @Test("Un ancien état sans statistiques reste décodable")
    func decodesLegacyState() throws {
        let payload = """
        {"progress":0.5,"dust":10,"title":"Novice","updatedAt":0}
        """

        let state = try JSONDecoder().decode(
            ComplicationState.self,
            from: Data(payload.utf8)
        )

        #expect(state.progress == 0.5)
        #expect(state.dust == 10)
        #expect(state.uniqueCount == 0)
        #expect(state.totalItems == 0)
        #expect(state.totalOpened == 0)
        #expect(state.rebirthLevel == 0)
        #expect(state.titleRank == 0)
        #expect(state.titleCount == 7)
    }

    @Test("L'instantané widget reflète les compteurs du magasin")
    func snapshotMirrorsStore() throws {
        let items = Fixtures.items(3)
        let fixture = try makeStore(
            items: items,
            draw: { _, _, _ in items }
        )

        _ = fixture.store.open(.common)
        let state = WidgetStatePublisher.makeState(
            from: fixture.store,
            updatedAt: .now
        )

        #expect(state.progress == 1)
        #expect(state.uniqueCount == 3)
        #expect(state.totalItems == 3)
        #expect(state.totalOpened == 1)
        #expect(state.rebirthLevel == 0)
        #expect(state.title == "Novice")
        #expect(state.nextTitle == "Explorateur")
        #expect(state.titleRank == 0)
        #expect(state.titleCount == ExplorerTitle.allCases.count)
    }
}
