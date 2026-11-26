import FirebaseFirestore
import Foundation
import Observation

/// Synchronisation de la progression d'un compte avec Firestore.
///
/// Le document distant `players/{uid}` reste la propriété exclusive du compte
/// authentifié. Les écritures sont regroupées deux secondes pour éviter un appel
/// par action locale, et chaque échec laisse la progression locale intacte.
@Observable
@MainActor
final class ProgressSync {
    /// Résolution d'un conflit entre la copie locale et la copie distante.
    enum Resolution: Equatable {
        /// La copie distante est plus récente, elle remplace la copie locale.
        case adoptRemote
        /// La copie locale doit être envoyée.
        case pushLocal
    }

    /// État exposé à l'interface.
    enum State: Equatable {
        /// Aucune opération en cours.
        case idle
        /// Écriture ou lecture en cours.
        case syncing
        /// Dernière synchronisation réussie.
        case synced(Date)
        /// Une opération a échoué et attend une reprise.
        case pending
    }

    /// Opération dont la reprise doit être relancée après un échec.
    private enum Failure: Equatable {
        /// La lecture distante a échoué : il faut relire, jamais écrire.
        case read
        /// L'écriture distante a échoué : la copie locale est à renvoyer.
        case write
    }

    /// Accès distant injectable, remplaçable dans les tests.
    struct Transport: Sendable {
        /// Lit le document du compte, `nil` s'il n'existe pas.
        let fetch: @Sendable () async throws -> ProgressSnapshot?
        /// Écrit le document du compte.
        let push: @Sendable (ProgressSnapshot) async throws -> Void
    }

    private let uid: String
    private let defaults: UserDefaults
    private let transport: Transport?
    private var snapshotProvider: (() -> ProgressSnapshot)?
    private var remoteApplier: ((ProgressSnapshot) -> Bool)?
    private var pushTask: Task<Void, Never>?
    private var isActive = true
    private var failure: Failure?

    /// Identifiant du compte synchronisé.
    var accountID: String { uid }

    private(set) var state: State = .idle

    /// Dernière erreur de synchronisation, `nil` après un succès.
    private(set) var lastError: AppError?

    /// Crée le synchroniseur d'un compte.
    ///
    /// - Parameters:
    ///   - uid: Identifiant Firebase du compte authentifié.
    ///   - defaults: Stockage des marqueurs de synchronisation.
    ///   - transport: Accès distant injecté, `nil` pour utiliser Firestore.
    init(uid: String, defaults: UserDefaults = .standard, transport: Transport? = nil) {
        self.uid = uid
        self.defaults = defaults
        self.transport = transport
    }

    /// Branche le magasin local au synchroniseur.
    ///
    /// - Parameters:
    ///   - snapshot: Fournit l'instantané courant.
    ///   - apply: Applique un instantané distant au magasin local et retourne
    ///     `false` si la progression n'a pas pu être appliquée.
    func attach(
        snapshot: @escaping () -> ProgressSnapshot,
        apply: @escaping (ProgressSnapshot) -> Bool
    ) {
        snapshotProvider = snapshot
        remoteApplier = apply
        isActive = true
    }

    /// Efface les marqueurs de synchronisation d'un compte.
    ///
    /// Appelé avant de supprimer le magasin local : sans marqueur, la prochaine
    /// lecture reprend le document Firestore au lieu de l'écraser avec un
    /// magasin vide.
    ///
    /// - Parameters:
    ///   - uid: Identifiant du compte.
    ///   - defaults: Stockage des marqueurs.
    static func clearMarkers(uid: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "sync.pending.\(uid)")
        defaults.removeObject(forKey: "sync.pushedAt.\(uid)")
        defaults.removeObject(forKey: "sync.verified.\(uid)")
    }

    /// Charge la progression distante, ou envoie la progression locale.
    func restore() async {
        guard let snapshotProvider else { return }
        guard AppPersistence.isValidAccountID(uid) else {
            state = .idle
            return
        }

        state = .syncing
        do {
            let remote = try await fetchRemote()
            guard isActive else { return }
            setVerified(true)
            switch Self.resolution(
                remote: remote,
                pendingLocal: isPending,
                lastPushedAt: lastPushedAt
            ) {
            case .adoptRemote:
                if let remote {
                    guard remoteApplier?(remote) != false else {
                        fail(with: AppError.invalidResponse, operation: .read)
                        return
                    }
                }
                succeed(at: remote?.updatedAt ?? .now)
            case .pushLocal:
                do {
                    try await push(snapshotProvider())
                } catch {
                    fail(with: error, operation: .write)
                }
            }
        } catch {
            fail(with: error, operation: .read)
        }
    }

    /// Signale une modification locale à envoyer.
    ///
    /// Aucun envoi n'est programmé tant que la copie distante n'a jamais été lue
    /// avec succès : écrire à l'aveugle écraserait la progression d'un autre
    /// appareil. Dans ce cas la reprise relit d'abord le document.
    func markDirty() {
        setPending(true)
        state = .pending
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.pushTask = nil
            if self.isVerified {
                await self.flush()
            } else {
                await self.restore()
            }
        }
    }

    /// Envoie immédiatement la progression courante.
    ///
    /// - Returns: `true` si l'écriture distante a réussi.
    @discardableResult
    func flush() async -> Bool {
        guard let snapshot = snapshotProvider?() else { return false }
        guard AppPersistence.isValidAccountID(uid), isActive else { return false }
        if !isVerified {
            await restore()
            if case .synced = state { return true }
            guard isVerified, isActive else { return false }
        }
        pushTask?.cancel()
        pushTask = nil
        state = .syncing
        do {
            try await push(snapshot)
            return true
        } catch {
            fail(with: error, operation: .write)
            return false
        }
    }

    /// Reprend l'opération qui a échoué.
    ///
    /// Une lecture échouée relance une lecture : renvoyer la copie locale à sa
    /// place écraserait une progression distante plus récente.
    func retry() {
        guard failure != nil, state != .syncing else { return }
        switch failure {
        case .read:
            Task { await restore() }
        case .write:
            guard isVerified else {
                Task { await restore() }
                return
            }
            markDirty()
        case nil:
            break
        }
    }

    /// Arrête les écritures différées, sans effacer la progression locale.
    ///
    /// Un envoi déjà en vol ne peut plus modifier les marqueurs du compte :
    /// `succeed` et `fail` ignorent une réponse reçue après la suspension.
    func suspend() {
        isActive = false
        pushTask?.cancel()
        pushTask = nil
    }

    /// Résout un conflit entre les deux copies.
    ///
    /// Une modification locale non envoyée gagne toujours : elle n'existe que
    /// sur cet appareil. Sinon la copie distante gagne si elle est plus récente
    /// que la dernière écriture connue.
    ///
    /// - Parameters:
    ///   - remote: Copie distante, `nil` si le document n'existe pas.
    ///   - pendingLocal: Indique une modification locale non envoyée.
    ///   - lastPushedAt: Date de la dernière écriture distante réussie.
    /// - Returns: La copie à conserver.
    static func resolution(
        remote: ProgressSnapshot?,
        pendingLocal: Bool,
        lastPushedAt: Date?
    ) -> Resolution {
        guard let remote else { return .pushLocal }
        guard !pendingLocal else { return .pushLocal }
        guard let lastPushedAt else { return .adoptRemote }
        return remote.updatedAt > lastPushedAt ? .adoptRemote : .pushLocal
    }

    private var document: DocumentReference {
        Firestore.firestore().document("players/\(uid)")
    }

    private func fetchRemote() async throws -> ProgressSnapshot? {
        if let transport {
            do {
                return try await FirestoreTask.bounded(transport.fetch)
            } catch {
                throw Self.map(error)
            }
        }
        let document = self.document
        do {
            let snapshot = try await FirestoreTask.bounded { try await document.getDocument() }
            guard snapshot.exists, let data = snapshot.data() else { return nil }
            guard let remote = ProgressSnapshot(firestoreData: data) else {
                throw AppError.invalidResponse
            }
            return remote
        } catch let error as AppError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private func push(_ snapshot: ProgressSnapshot) async throws {
        do {
            if let transport {
                try await FirestoreTask.bounded { try await transport.push(snapshot) }
            } else {
                let document = self.document
                try await FirestoreTask.bounded { try await document.setData(snapshot.firestoreFields) }
            }
            succeed(at: snapshot.updatedAt)
        } catch {
            throw Self.map(error)
        }
    }

    private func fail(with error: Error, operation: Failure) {
        guard isActive else { return }
        lastError = error as? AppError ?? Self.map(error)
        failure = operation
        if operation == .read {
            setVerified(false)
        }
        state = .pending
    }

    private func succeed(at date: Date) {
        guard isActive else { return }
        setPending(false)
        lastError = nil
        failure = nil
        defaults.set(date, forKey: pushedKey)
        state = .synced(date)
    }

    private static func map(_ error: Error) -> AppError {
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

    private var isPending: Bool {
        defaults.bool(forKey: pendingKey)
    }

    /// Indique que le document distant a déjà été lu avec succès.
    ///
    /// Persisté : un envoi n'est autorisé qu'après une lecture réussie, pour ne
    /// jamais écraser une progression distante inconnue.
    private var isVerified: Bool {
        defaults.bool(forKey: verifiedKey)
    }

    private func setVerified(_ verified: Bool) {
        defaults.set(verified, forKey: verifiedKey)
    }

    private var lastPushedAt: Date? {
        defaults.object(forKey: pushedKey) as? Date
    }

    private var pendingKey: String { "sync.pending.\(uid)" }
    private var pushedKey: String { "sync.pushedAt.\(uid)" }
    private var verifiedKey: String { "sync.verified.\(uid)" }

    private func setPending(_ pending: Bool) {
        defaults.set(pending, forKey: pendingKey)
    }
}

nonisolated extension ProgressSnapshot {
    /// Champs envoyés à Firestore.
    var firestoreFields: [String: Any] {
        [
            "dust": dust,
            "rebirthLevel": rebirthLevel,
            "marketPurchases": marketPurchases,
            "marketSales": marketSales,
            "owned": owned,
            "marketStock": marketStock,
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    /// Décode un document Firestore en bornant toutes les valeurs.
    ///
    /// - Parameter data: Champs bruts du document.
    /// - Returns: L'instantané, ou `nil` si les types ou les bornes sont invalides.
    init?(firestoreData data: [String: Any]) {
        guard let dust = data["dust"] as? Int,
              let rebirthLevel = data["rebirthLevel"] as? Int,
              let marketPurchases = data["marketPurchases"] as? Int,
              let marketSales = data["marketSales"] as? Int else {
            return nil
        }
        guard let updatedDate = Self.date(data["updatedAt"]) else { return nil }
        guard let owned = Self.intMap(data["owned"]),
              let marketStock = Self.intMap(data["marketStock"]) else {
            return nil
        }
        self.init(
            dust: dust,
            rebirthLevel: rebirthLevel,
            marketPurchases: marketPurchases,
            marketSales: marketSales,
            owned: owned,
            marketStock: marketStock,
            updatedAt: updatedDate
        )
    }

    private static func date(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        return value as? Date
    }

    private static func intMap(_ value: Any?) -> [String: Int]? {
        guard let raw = value as? [String: Any], raw.count <= maximumEntries else { return nil }
        var result: [String: Int] = [:]
        result.reserveCapacity(raw.count)
        for (key, entry) in raw {
            guard let number = entry as? Int else { return nil }
            result[key] = number
        }
        return result
    }
}
