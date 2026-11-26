import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("Progression distante")
struct ProgressSnapshotTests {
    @Test("Un instantané borne les valeurs négatives et les identifiants invalides")
    func sanitizesValues() {
        let snapshot = ProgressSnapshot(
            dust: -10,
            rebirthLevel: -2,
            marketPurchases: -1,
            marketSales: 4,
            owned: ["dirt": 0, "BAD": 2, "Oak Log": 3, "oak_log": 50_000],
            marketStock: ["stone": 2],
            updatedAt: .now
        )

        #expect(snapshot.dust == 0)
        #expect(snapshot.rebirthLevel == 0)
        #expect(snapshot.marketPurchases == 0)
        #expect(snapshot.marketSales == 4)
        #expect(snapshot.owned == ["oak_log": ProgressSnapshot.maximumQuantity])
        #expect(snapshot.marketStock == ["stone": 2])
    }

    @Test("Un instantané respecte les bornes des règles Firestore")
    func clampsToRuleLimits() {
        let snapshot = ProgressSnapshot(
            dust: Int.max,
            rebirthLevel: Int.max,
            marketPurchases: Int.max,
            marketSales: Int.max,
            owned: [:],
            marketStock: [:],
            updatedAt: .now
        )

        #expect(snapshot.dust == ProgressSnapshot.maximumCounter)
        #expect(snapshot.rebirthLevel == ProgressSnapshot.maximumRebirthLevel)
        #expect(snapshot.marketPurchases == ProgressSnapshot.maximumCounter)
        #expect(snapshot.marketSales == ProgressSnapshot.maximumCounter)
    }

    @Test("L'instantané Firestore contient exactement les champs des règles")
    func matchesRuleSchema() {
        let snapshot = ProgressSnapshot.empty(updatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(Set(snapshot.firestoreFields.keys) == Set([
            "dust",
            "rebirthLevel",
            "marketPurchases",
            "marketSales",
            "owned",
            "marketStock",
            "updatedAt"
        ]))
    }

    @Test("Un instantané survit à un aller-retour Firestore")
    func roundTripsThroughFirestore() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.25)
        let snapshot = ProgressSnapshot(
            dust: 128,
            rebirthLevel: 3,
            marketPurchases: 5,
            marketSales: 2,
            owned: ["dirt": 4, "stone": 1],
            marketStock: ["dirt": 0, "stone": 1],
            updatedAt: date
        )

        let decoded = try #require(ProgressSnapshot(firestoreData: snapshot.firestoreFields))

        #expect(decoded == snapshot)
    }

    @Test("Un document aux types invalides est refusé")
    func rejectsInvalidTypes() {
        let fields: [String: Any] = [
            "dust": "128",
            "rebirthLevel": 0,
            "marketPurchases": 0,
            "marketSales": 0,
            "owned": [String: Any](),
            "marketStock": [String: Any](),
            "updatedAt": Date()
        ]

        #expect(ProgressSnapshot(firestoreData: fields) == nil)
    }

    @Test("Un document démesuré est refusé")
    func rejectsOversizedDocument() {
        var owned: [String: Any] = [:]
        for index in 0...ProgressSnapshot.maximumEntries {
            owned["item_\(index)"] = 1
        }
        let fields: [String: Any] = [
            "dust": 0,
            "rebirthLevel": 0,
            "marketPurchases": 0,
            "marketSales": 0,
            "owned": owned,
            "marketStock": [String: Any](),
            "updatedAt": Date(timeIntervalSince1970: 1_700_000_000)
        ]

        #expect(ProgressSnapshot(firestoreData: fields) == nil)
    }
}

@MainActor
@Suite("Résolution de synchronisation")
struct SyncResolutionTests {
    private let remote = ProgressSnapshot(
        dust: 10,
        rebirthLevel: 0,
        marketPurchases: 0,
        marketSales: 0,
        owned: [:],
        marketStock: [:],
        updatedAt: Date(timeIntervalSince1970: 2_000)
    )

    @Test("Sans document distant, la copie locale est envoyée")
    func pushesWhenRemoteMissing() {
        #expect(ProgressSync.resolution(remote: nil, pendingLocal: false, lastPushedAt: nil) == .pushLocal)
    }

    @Test("Après effacement des marqueurs, une copie vide reprend le document distant")
    func clearedMarkersAdoptRemote() {
        #expect(ProgressSync.resolution(remote: remote, pendingLocal: false, lastPushedAt: nil) == .adoptRemote)
    }

    @Test("Une modification locale non envoyée gagne toujours")
    func localPendingWins() {
        #expect(
            ProgressSync.resolution(
                remote: remote,
                pendingLocal: true,
                lastPushedAt: Date(timeIntervalSince1970: 1_000)
            ) == .pushLocal
        )
    }

    @Test("Un document distant plus récent remplace la copie locale")
    func adoptsNewerRemote() {
        #expect(
            ProgressSync.resolution(
                remote: remote,
                pendingLocal: false,
                lastPushedAt: Date(timeIntervalSince1970: 1_000)
            ) == .adoptRemote
        )
    }

    @Test("Un document distant plus ancien laisse la copie locale gagner")
    func keepsRecentLocal() {
        #expect(
            ProgressSync.resolution(
                remote: remote,
                pendingLocal: false,
                lastPushedAt: Date(timeIntervalSince1970: 3_000)
            ) == .pushLocal
        )
    }

    @Test("Une première connexion sans marqueur local reprend le document distant")
    func adoptsOnFirstLaunch() {
        #expect(ProgressSync.resolution(remote: remote, pendingLocal: false, lastPushedAt: nil) == .adoptRemote)
    }
}
