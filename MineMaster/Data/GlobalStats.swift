import FirebaseFirestore
import Foundation
import Observation

/// Agrégat communautaire d'un item.
nonisolated struct GlobalItemStats: Sendable, Equatable {
    /// Plafond appliqué à tout compteur reçu du réseau.
    static let maximumCounter = 1_000_000_000

    /// Nombre de tirages mondiaux.
    let pulls: Int
    /// Nombre d'échanges mondiaux au marché.
    let marketTrades: Int
    /// Date de la dernière écriture connue.
    let updatedAt: Date

    /// Construit un agrégat en bornant les compteurs.
    ///
    /// - Parameters:
    ///   - pulls: Tirages mondiaux, ramenés entre `0` et `maximumCounter`.
    ///   - marketTrades: Échanges mondiaux, ramenés entre `0` et `maximumCounter`.
    ///   - updatedAt: Date de référence.
    init(pulls: Int, marketTrades: Int, updatedAt: Date) {
        self.pulls = min(max(pulls, 0), Self.maximumCounter)
        self.marketTrades = min(max(marketTrades, 0), Self.maximumCounter)
        self.updatedAt = updatedAt
    }

    /// Décode un document Firestore en bornant les valeurs.
    ///
    /// - Parameter data: Champs bruts du document.
    /// - Returns: L'agrégat, ou `nil` si les types ou la date sont invalides.
    init?(firestoreData data: [String: Any]) {
        guard let pulls = data["pulls"] as? Int,
              let marketTrades = data["marketTrades"] as? Int,
              let updatedAt = Self.date(data["updatedAt"]) else {
            return nil
        }
        self.init(pulls: pulls, marketTrades: marketTrades, updatedAt: updatedAt)
    }

    private static func date(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        return value as? Date
    }
}

/// Synchronise les compteurs communautaires avec Firestore.
///
/// Les tirages et les échanges sont agrégés par item, mis à jour de façon
/// optimiste dans l'interface, puis envoyés par lots bornés. Les compteurs sont
/// fournis par les clients authentifiés : ils restent indicatifs, bornés côté
/// règles, et ne remplacent jamais la progression du compte.
@Observable
@MainActor
final class GlobalStatsSync {
    /// Incréments en attente d'envoi pour un item.
    nonisolated struct Delta: Sendable, Equatable {
        /// Tirages à ajouter.
        var pulls = 0
        /// Échanges à ajouter.
        var marketTrades = 0

        /// Indique qu'aucun compteur ne change.
        var isEmpty: Bool { pulls == 0 && marketTrades == 0 }
    }

    /// Accès distant injectable, remplaçable dans les tests.
    nonisolated struct Transport: Sendable {
        /// Lit tous les agrégats connus.
        let fetch: @Sendable () async throws -> [String: GlobalItemStats]
        /// Envoie les incréments agrégés.
        let push: @Sendable ([String: Delta]) async throws -> Void
    }

    /// Nombre maximal d'items lus en une passe.
    nonisolated private static let fetchLimit = 1_000
    /// Délai de regroupement des écritures.
    nonisolated private static let flushDelay = 1.5

    private let transport: Transport?
    private var pending: [String: Delta] = [:]
    private var flushTask: Task<Void, Never>?

    /// Agrégats connus, indexés par identifiant d'item.
    private(set) var stats: [String: GlobalItemStats] = [:]
    /// Indique une lecture en cours.
    private(set) var isLoading = false
    /// Indique qu'une lecture a déjà réussi.
    private(set) var hasLoaded = false
    /// Dernière erreur de lecture ou d'écriture, `nil` après un succès.
    private(set) var lastError: AppError?

    /// Crée le synchroniseur communautaire.
    ///
    /// - Parameter transport: Accès distant injecté, `nil` pour utiliser Firestore.
    init(transport: Transport? = nil) {
        self.transport = transport
    }

    /// Total des tirages mondiaux connus.
    var totalPulls: Int {
        stats.values.reduce(0) { $0 + $1.pulls }
    }

    /// Total des échanges mondiaux connus.
    var totalTrades: Int {
        stats.values.reduce(0) { $0 + $1.marketTrades }
    }

    /// Nombre de tirages mondiaux d'un item.
    ///
    /// - Parameter id: Identifiant du catalogue.
    /// - Returns: Le compteur connu, `0` si absent.
    func pulls(for id: String) -> Int {
        stats[id]?.pulls ?? 0
    }

    /// Nombre d'échanges mondiaux d'un item.
    ///
    /// - Parameter id: Identifiant du catalogue.
    /// - Returns: Le compteur connu, `0` si absent.
    func trades(for id: String) -> Int {
        stats[id]?.marketTrades ?? 0
    }

    /// Charge les agrégats depuis Firestore.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let remote: [String: GlobalItemStats]
            if let transport {
                remote = try await FirestoreTask.bounded { try await transport.fetch() }
            } else {
                remote = try await FirestoreTask.bounded { try await Self.fetchRemote() }
            }
            stats = remote
            hasLoaded = true
            lastError = nil
        } catch {
            lastError = Self.map(error)
        }
    }

    /// Enregistre des tirages pour une ou plusieurs cartes.
    ///
    /// - Parameter ids: Identifiants des items tirés.
    func recordPulls(_ ids: [String]) {
        for id in ids {
            enqueue(id, pulls: 1, trades: 0)
        }
    }

    /// Enregistre un échange au marché.
    ///
    /// - Parameter id: Identifiant de l'item échangé.
    func recordMarketTrade(_ id: String) {
        enqueue(id, pulls: 0, trades: 1)
    }

    /// Envoie immédiatement les incréments en attente.
    func flush() async {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll()

        do {
            if let transport {
                try await FirestoreTask.bounded { try await transport.push(batch) }
            } else {
                try await FirestoreTask.bounded { try await Self.pushRemote(batch) }
            }
            lastError = nil
        } catch {
            for (id, delta) in batch {
                var merged = pending[id] ?? Delta()
                merged.pulls += delta.pulls
                merged.marketTrades += delta.marketTrades
                pending[id] = merged
            }
            lastError = Self.map(error)
        }
    }

    private func enqueue(_ id: String, pulls: Int, trades: Int) {
        guard ProgressSnapshot.isSafeIdentifier(id) else { return }

        var delta = pending[id] ?? Delta()
        delta.pulls += pulls
        delta.marketTrades += trades
        pending[id] = delta

        if let current = stats[id] {
            stats[id] = GlobalItemStats(
                pulls: current.pulls + pulls,
                marketTrades: current.marketTrades + trades,
                updatedAt: .now
            )
        }

        if delta.pulls >= 5 || delta.marketTrades >= 5 {
            flushTask?.cancel()
            flushTask = Task { [weak self] in
                await self?.flush()
            }
        } else {
            scheduleFlush()
        }
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.flushDelay))
            guard !Task.isCancelled, let self else { return }
            self.flushTask = nil
            await self.flush()
        }
    }

    nonisolated private static func fetchRemote() async throws -> [String: GlobalItemStats] {
        let snapshot = try await Firestore.firestore()
            .collection("globalItems")
            .limit(to: fetchLimit)
            .getDocuments()
        var result: [String: GlobalItemStats] = [:]
        for document in snapshot.documents where ProgressSnapshot.isSafeIdentifier(document.documentID) {
            if let stats = GlobalItemStats(firestoreData: document.data()) {
                result[document.documentID] = stats
            }
        }
        return result
    }

    nonisolated private static func pushRemote(_ deltas: [String: Delta]) async throws {
        guard !deltas.isEmpty else { return }
        let database = Firestore.firestore()
        let batch = database.batch()
        for (id, delta) in deltas where ProgressSnapshot.isSafeIdentifier(id) && !delta.isEmpty {
            let reference = database.collection("globalItems").document(id)
            let fields: [String: Any] = [
                "pulls": FieldValue.increment(Int64(delta.pulls)),
                "marketTrades": FieldValue.increment(Int64(delta.marketTrades)),
                "updatedAt": Timestamp(date: .now)
            ]
            batch.setData(fields, forDocument: reference, merge: true)
        }
        try await batch.commit()
    }

    nonisolated private static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: return .syncRejected
            case 8: return .rateLimited
            case 14, 4: return .offline
            default: return .invalidResponse
            }
        }
        if nsError.domain == NSURLErrorDomain { return .offline }
        return .invalidResponse
    }
}
