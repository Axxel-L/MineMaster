import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("Garde d'écriture distante")
struct ProgressSyncGateTests {
    private static let accountID = "accountSYNC123"

    private func makeDefaults() -> UserDefaults {
        let suite = "progress-sync-tests"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("sync.") {
            defaults.removeObject(forKey: key)
        }
        return defaults
    }

    private func makeSync(
        defaults: UserDefaults,
        fetch: @escaping @Sendable () async throws -> ProgressSnapshot?,
        pushed: @escaping @Sendable (ProgressSnapshot) -> Void
    ) -> ProgressSync {
        ProgressSync(
            uid: Self.accountID,
            defaults: defaults,
            transport: .init(
                fetch: fetch,
                push: { snapshot in pushed(snapshot) }
            )
        )
    }

    @Test("Sans lecture réussie, aucune écriture distante n'est émise")
    func refusesPushBeforeVerifiedRead() async {
        let defaults = makeDefaults()
        let pushes = Counter()
        let sync = makeSync(
            defaults: defaults,
            fetch: { throw AppError.offline },
            pushed: { _ in pushes.increment() }
        )
        sync.attach(snapshot: { ProgressSnapshot.empty() }, apply: { _ in true })

        await sync.flush()

        #expect(pushes.value == 0)
        #expect(sync.lastError == .offline)
    }

    @Test("Après une lecture réussie, l'écriture distante est autorisée")
    func pushesAfterVerifiedRead() async {
        let defaults = makeDefaults()
        let pushes = Counter()
        let sync = makeSync(
            defaults: defaults,
            fetch: { nil },
            pushed: { _ in pushes.increment() }
        )
        sync.attach(snapshot: { ProgressSnapshot.empty() }, apply: { _ in true })

        let sent = await sync.flush()

        #expect(sent)
        #expect(pushes.value == 1)
    }

    @Test("Une lecture en échec révoque l'autorisation d'écriture")
    func failedReadRevokesVerification() async {
        let defaults = makeDefaults()
        let pushes = Counter()
        let failing = Counter()
        let sync = makeSync(
            defaults: defaults,
            fetch: {
                if failing.value == 0 {
                    failing.increment()
                    return nil
                }
                throw AppError.timeout
            },
            pushed: { _ in pushes.increment() }
        )
        sync.attach(snapshot: { ProgressSnapshot.empty() }, apply: { _ in true })

        await sync.flush()
        #expect(pushes.value == 1)

        await sync.restore()
        #expect(sync.lastError == .timeout)

        await sync.flush()
        #expect(pushes.value == 1)
    }

    @Test("Une application distante refusée n'est jamais comptée comme synchronisée")
    func refusedApplyIsNotSuccess() async {
        let defaults = makeDefaults()
        let remote = ProgressSnapshot(
            dust: 5,
            rebirthLevel: 0,
            marketPurchases: 0,
            marketSales: 0,
            owned: [:],
            marketStock: [:],
            updatedAt: .now
        )
        let sync = makeSync(
            defaults: defaults,
            fetch: { remote },
            pushed: { _ in }
        )
        sync.attach(snapshot: { ProgressSnapshot.empty() }, apply: { _ in false })

        await sync.restore()

        #expect(sync.lastError == .invalidResponse)
        #expect(sync.state == .pending)
    }

    @Test("Un synchroniseur suspendu ne se déclare pas synchronisé")
    func suspendedNeverReportsSuccess() async {
        let defaults = makeDefaults()
        let sync = makeSync(defaults: defaults, fetch: { nil }, pushed: { _ in })
        sync.attach(snapshot: { ProgressSnapshot.empty() }, apply: { _ in true })
        sync.suspend()

        let sent = await sync.flush()

        #expect(!sent)
        guard case .synced = sync.state else { return }
        Issue.record("Un synchroniseur suspendu ne doit jamais exposer un état synchronisé")
    }
}

/// Compteur partageable entre tâches de test.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}
