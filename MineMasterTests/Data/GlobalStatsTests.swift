import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("Statistiques mondiales")
struct GlobalStatsTests {
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Un agrégat borne les compteurs négatifs et démesurés")
    func clampsCounters() {
        let stats = GlobalItemStats(
            pulls: -4,
            marketTrades: Int.max,
            updatedAt: baseDate
        )

        #expect(stats.pulls == 0)
        #expect(stats.marketTrades == GlobalItemStats.maximumCounter)
    }

    @Test("Un document aux types invalides est refusé")
    func rejectsInvalidDocument() {
        #expect(GlobalItemStats(firestoreData: [
            "pulls": "12",
            "marketTrades": 3,
            "updatedAt": baseDate
        ]) == nil)
        #expect(GlobalItemStats(firestoreData: [
            "pulls": 12,
            "marketTrades": 3
        ]) == nil)
    }

    @Test("Les tirages et échanges sont agrégés puis envoyés en un lot")
    func aggregatesAndFlushes() async {
        let recorder = StatsRecorder()
        let sync = GlobalStatsSync(
            transport: .init(
                fetch: { Self.remote },
                push: { deltas in recorder.record(deltas) }
            )
        )

        await sync.refresh()
        sync.recordPulls(["dirt", "stone", "dirt"])
        sync.recordMarketTrade("dirt")

        #expect(sync.pulls(for: "dirt") == 12)
        #expect(sync.trades(for: "dirt") == 4)

        await sync.flush()

        let batch = recorder.lastBatch
        #expect(batch?["dirt"] == GlobalStatsSync.Delta(pulls: 2, marketTrades: 1))
        #expect(batch?["stone"] == GlobalStatsSync.Delta(pulls: 1, marketTrades: 0))
    }

    @Test("Un envoi refusé conserve les incréments pour la reprise")
    func failedPushKeepsPending() async {
        let recorder = StatsRecorder()
        recorder.shouldFail = true
        let sync = GlobalStatsSync(
            transport: .init(
                fetch: { [String: GlobalItemStats]() },
                push: { deltas in
                    try recorder.recordOrThrow(deltas)
                }
            )
        )

        sync.recordPulls(["dirt"])
        await sync.flush()
        #expect(sync.lastError != nil)

        recorder.shouldFail = false
        await sync.flush()

        #expect(recorder.lastBatch?["dirt"]?.pulls == 1)
    }

    @Test("Une lecture réussie alimente les totaux et les compteurs")
    func refreshFeedsTotals() async {
        let sync = GlobalStatsSync(
            transport: .init(
                fetch: { Self.remote },
                push: { _ in }
            )
        )

        await sync.refresh()

        #expect(sync.hasLoaded)
        #expect(sync.totalPulls == 12)
        #expect(sync.totalTrades == 4)
        #expect(sync.pulls(for: "dirt") == 10)
        #expect(sync.trades(for: "dirt") == 3)
    }

    private nonisolated static let remote: [String: GlobalItemStats] = [
        "dirt": GlobalItemStats(pulls: 10, marketTrades: 3, updatedAt: Date(timeIntervalSince1970: 1_700_000_000)),
        "stone": GlobalItemStats(pulls: 2, marketTrades: 1, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    ]
}

/// Capture les lots d'incréments envoyés par le synchroniseur.
private final class StatsRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var batches: [[String: GlobalStatsSync.Delta]] = []
    private var failNext = false

    var shouldFail: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return failNext
        }
        set {
            lock.lock()
            failNext = newValue
            lock.unlock()
        }
    }

    var lastBatch: [String: GlobalStatsSync.Delta]? {
        lock.lock()
        defer { lock.unlock() }
        return batches.last
    }

    func record(_ deltas: [String: GlobalStatsSync.Delta]) {
        lock.lock()
        batches.append(deltas)
        lock.unlock()
    }

    func recordOrThrow(_ deltas: [String: GlobalStatsSync.Delta]) throws {
        lock.lock()
        let failing = failNext
        if !failing {
            batches.append(deltas)
        }
        lock.unlock()
        if failing {
            throw AppError.syncRejected
        }
    }
}
