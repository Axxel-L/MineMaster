import Foundation

/// Exécute les commandes de la montre contre le magasin de l'iPhone.
///
/// L'iPhone reste l'unique source de vérité : la montre ne modifie jamais sa
/// propre progression, elle demande une action et reçoit l'état résultant.
@MainActor
final class WatchCommandRouter {
    private let store: GameStore
    private let stats: GlobalStatsSync
    private var cachedReplies: [UUID: WatchReply] = [:]
    private var replyOrder: [UUID] = []
    private var lastOpenAt: Date?
    private var lastStatsRefresh: Date?

    private static let maximumCachedReplies = 64
    private static let openingWatchdog: TimeInterval = 120
    private static let statsCooldown: TimeInterval = 5

    /// Crée le routeur d'un compte authentifié.
    ///
    /// - Parameters:
    ///   - store: Magasin local de l'iPhone.
    ///   - stats: Agrégats communautaires du compte.
    init(store: GameStore, stats: GlobalStatsSync) {
        self.store = store
        self.stats = stats
    }

    /// Construit l'état complet à envoyer à la montre.
    ///
    /// - Returns: Progression, compteurs locaux et totaux communautaires.
    func state() -> WatchState {
        WatchState(
            snapshot: store.progressSnapshot(),
            totalOpened: store.totalOpened,
            globalPulls: stats.totalPulls,
            globalTrades: stats.totalTrades,
            globalLoaded: stats.hasLoaded
        )
    }

    /// Exécute une commande de façon idempotente.
    ///
    /// - Parameter command: Commande validée par le transport.
    /// - Returns: La réponse à renvoyer à la montre.
    func handle(_ command: WatchCommand) async -> WatchReply {
        if let cached = cachedReplies[command.id] {
            return cached
        }
        let reply = await execute(command)
        cache(reply)
        return reply
    }

    private func execute(_ command: WatchCommand) async -> WatchReply {
        switch command.action {
        case .state:
            return .state(state(), commandID: command.id)
        case .plan:
            expireStaleOpening()
            guard let plan = store.planOpening() else {
                return .failure("Catalogue indisponible ou ouverture en cours.", commandID: command.id)
            }
            return .plan(WatchPlan(booster: plan.booster, kind: plan.kind), commandID: command.id)
        case .open:
            return open(command)
        case .close:
            store.endOpening()
            lastOpenAt = nil
            return .state(state(), commandID: command.id)
        case .buy:
            return transact(command) { item in try store.buy(item) }
        case .sell:
            return transact(command) { item in try store.sell(item.id) }
        case .rebirth:
            do {
                try store.rebirth()
                lastOpenAt = nil
                return .state(state(), commandID: command.id)
            } catch let error as AppError {
                return .failure(error.errorDescription ?? "Renaissance impossible.", commandID: command.id)
            } catch {
                return .failure("Renaissance impossible.", commandID: command.id)
            }
        case .refreshStats:
            await refreshStatsIfNeeded(force: true)
            return .state(state(), commandID: command.id)
        case .item:
            await refreshStatsIfNeeded(force: false)
            return item(command)
        }
    }

    private func open(_ command: WatchCommand) -> WatchReply {
        expireStaleOpening()
        guard let booster = command.booster,
              let kind = command.kind else {
            return .failure("Plan d'ouverture invalide.", commandID: command.id)
        }
        let results = store.open(booster, kind: kind)
        guard !results.isEmpty else {
            return .failure("Ouverture impossible : catalogue vide ou session en cours.", commandID: command.id)
        }
        lastOpenAt = .now
        let cards = results.map { WatchDraw(itemID: $0.item.id, dust: $0.dust, isNew: $0.isNew) }
        return .opened(
            WatchOpenResult(
                plan: WatchPlan(booster: booster, kind: kind),
                cards: cards,
                state: state()
            ),
            commandID: command.id
        )
    }

    private func transact(
        _ command: WatchCommand,
        action: (CatalogItem) throws -> Void
    ) -> WatchReply {
        guard let id = command.itemID,
              ProgressSnapshot.isSafeIdentifier(id),
              let item = store.catalog.first(where: { $0.id == id }) else {
            return .failure("Item inconnu.", commandID: command.id)
        }
        do {
            try action(item)
            return .state(state(), commandID: command.id)
        } catch let error as AppError {
            return .failure(error.errorDescription ?? "Transaction refusée.", commandID: command.id)
        } catch {
            return .failure("Transaction refusée.", commandID: command.id)
        }
    }

    private func item(_ command: WatchCommand) -> WatchReply {
        guard let id = command.itemID,
              ProgressSnapshot.isSafeIdentifier(id),
              let item = store.catalog.first(where: { $0.id == id }) else {
            return .failure("Item inconnu.", commandID: command.id)
        }
        let counters = WatchItemStats(
            localPulls: store.pullCount(for: item),
            globalPulls: stats.pulls(for: id),
            globalTrades: stats.trades(for: id),
            updatedAt: .now
        )
        return .item(counters, commandID: command.id)
    }

    private func refreshStatsIfNeeded(force: Bool) async {
        if !force, let lastStatsRefresh, Date.now.timeIntervalSince(lastStatsRefresh) < Self.statsCooldown {
            return
        }
        lastStatsRefresh = .now
        await stats.refresh()
    }

    private func expireStaleOpening() {
        guard store.isOpening else { return }
        guard let lastOpenAt, Date.now.timeIntervalSince(lastOpenAt) > Self.openingWatchdog else { return }
        store.endOpening()
        self.lastOpenAt = nil
    }

    private func cache(_ reply: WatchReply) {
        cachedReplies[reply.commandID] = reply
        replyOrder.append(reply.commandID)
        if replyOrder.count > Self.maximumCachedReplies {
            let expired = replyOrder.removeFirst()
            cachedReplies.removeValue(forKey: expired)
        }
    }
}
