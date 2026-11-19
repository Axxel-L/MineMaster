import Testing
@testable import MineMaster

@MainActor
@Suite("Titres d'explorateur")
struct ExplorerTitleTests {
    @Test("Le titre courant suit les seuils d'items uniques")
    func currentTitleFollowsThresholds() {
        #expect(ExplorerTitle.current(for: 0) == .novice)
        #expect(ExplorerTitle.current(for: 14) == .novice)
        #expect(ExplorerTitle.current(for: 15) == .explorer)
        #expect(ExplorerTitle.current(for: 49) == .explorer)
        #expect(ExplorerTitle.current(for: 50) == .prospector)
        #expect(ExplorerTitle.current(for: 254) == .worldMaster)
        #expect(ExplorerTitle.current(for: 999) == .worldMaster)
    }

    @Test("Le prochain titre est le premier seuil non atteint")
    func nextTitleIsFirstLockedThreshold() {
        #expect(ExplorerTitle.next(for: 0) == .explorer)
        #expect(ExplorerTitle.next(for: 99) == .collector)
        #expect(ExplorerTitle.next(for: 254) == nil)
    }

    @Test("Les seuils sont strictement croissants")
    func thresholdsAreStrictlyIncreasing() {
        let thresholds = ExplorerTitle.allCases.map(\.requiredItems)

        #expect(thresholds.first == 0)
        #expect(zip(thresholds, thresholds.dropFirst()).allSatisfy { $0 < $1 })
    }
}
