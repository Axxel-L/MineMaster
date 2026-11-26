import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Lien entre la montre et l'iPhone maître de la progression.
///
/// La montre ne modifie jamais sa collection directement : chaque action part
/// vers l'iPhone, qui l'exécute et renvoie l'état résultant. Hors connexion,
/// l'écran reste consultable en lecture seule.
@Observable
@MainActor
final class WatchLink {
    /// Mode de fonctionnement du lien.
    enum Mode: Sendable {
        case live
        case local
    }

    private let store: GameStore
    private let mode: Mode
    private var relay: WatchSessionRelay?
    private var started = false
    private var pending: [UUID: CheckedContinuation<WatchReply, Never>] = [:]
    private var timeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var closeTask: Task<Void, Never>?
    private var pendingState: WatchState?
    private var lastErrorValue: String?

    private(set) var isActivated = false
    private(set) var isReachable = false
    private(set) var isLocked: Bool
    private(set) var state: WatchState?

    private static let replyTimeout: Duration = .seconds(8)
    private static let lockedKey = "watch.locked"

    /// Crée le lien d'une montre.
    ///
    /// - Parameters:
    ///   - store: Magasin local servant de cache d'affichage.
    ///   - mode: Mode réel ou déterministe réservé aux tests.
    init(store: GameStore, mode: Mode) {
        self.store = store
        self.mode = mode
        isLocked = mode == .local ? false : UserDefaults.standard.bool(forKey: Self.lockedKey)
        if mode == .local {
            isActivated = true
            isReachable = true
            state = localState()
        }
    }

    /// Indique que la montre joue sur son propre magasin.
    var isLocal: Bool {
        mode == .local
    }

    /// Indique qu'une action peut être demandée.
    var canPlay: Bool {
        mode == .local || (isActivated && isReachable && !isLocked)
    }

    /// Nombre d'ouvertures affiché, issu du dernier état reçu.
    var totalOpened: Int {
        state?.totalOpened ?? store.totalOpened
    }

    /// Tirages mondiaux connus.
    var globalPulls: Int {
        state?.globalPulls ?? 0
    }

    /// Échanges mondiaux connus.
    var globalTrades: Int {
        state?.globalTrades ?? 0
    }

    /// Indique que les agrégats communautaires ont été lus.
    var globalLoaded: Bool {
        state?.globalLoaded ?? false
    }

    /// Dernière erreur affichable, `nil` après une réussite.
    var lastError: String? {
        lastErrorValue
    }

    /// Active la session de communication une seule fois.
    func start() {
        guard mode == .live, !started else { return }
        started = true
        guard WCSession.isSupported() else {
            isLocked = true
            return
        }
        let relay = WatchSessionRelay(
            onPacket: { [weak self] packet in
                Task { @MainActor in self?.handle(packet) }
            },
            onReachability: { [weak self] reachable in
                Task { @MainActor in self?.reachabilityChanged(reachable) }
            },
            onActivation: { [weak self] active in
                Task { @MainActor in self?.activationChanged(active) }
            },
            onReactivate: {}
        )
        self.relay = relay
        WCSession.default.delegate = relay
        WCSession.default.activate()
    }

    /// Applique l'état en attente une fois le catalogue local chargé.
    func applyPending() {
        if mode == .local {
            state = localState()
            updateComplication()
            return
        }
        if isLocked {
            _ = store.applyRemote(.empty())
            updateComplication()
            return
        }
        guard let pendingState, !store.catalog.isEmpty else { return }
        guard store.applyRemote(pendingState.snapshot) else { return }
        self.pendingState = nil
        updateComplication()
    }

    /// Demande un plan d'ouverture à l'iPhone.
    ///
    /// - Returns: Le plan affichable sur le pack scellé, `nil` en cas d'échec.
    func plan() async -> OpeningPlan? {
        if let closeTask {
            await closeTask.value
            self.closeTask = nil
        }
        let reply = await send(WatchCommand(action: .plan))
        guard reply.kind == .plan,
              let plan = reply.plan,
              let booster = plan.booster,
              let kind = plan.kind else {
            recordFailure(reply, fallback: "Plan indisponible.")
            return nil
        }
        lastErrorValue = nil
        return OpeningPlan(booster: booster, kind: kind)
    }

    /// Demande l'ouverture réelle d'un pack.
    ///
    /// - Parameter plan: Plan affiché sur le pack scellé.
    /// - Returns: Les cinq cartes et l'état résultant, `nil` en cas d'échec.
    func open(_ plan: OpeningPlan) async -> WatchOpenResult? {
        let reply = await send(WatchCommand(action: .open, booster: plan.booster, kind: plan.kind))
        guard reply.kind == .opened, let opened = reply.opened else {
            recordFailure(reply, fallback: "Ouverture impossible.")
            return nil
        }
        lastErrorValue = nil
        return opened
    }

    /// Libère la session d'ouverture côté iPhone.
    func closeOpening() {
        guard mode == .live else {
            store.endOpening()
            return
        }
        guard canPlay else { return }
        closeTask = Task { [weak self] in
            guard let self else { return }
            _ = await send(WatchCommand(action: .close))
        }
    }

    /// Achète un item au marché du compte.
    ///
    /// - Parameter item: Item à acheter.
    /// - Returns: Un message d'erreur, `nil` en cas de succès.
    func buy(_ item: CatalogItem) async -> String? {
        await transact(WatchCommand(action: .buy, itemID: item.id), fallback: "Achat refusé.")
    }

    /// Vend un exemplaire d'un item au marché du compte.
    ///
    /// - Parameter itemID: Identifiant de l'item.
    /// - Returns: Un message d'erreur, `nil` en cas de succès.
    func sell(_ itemID: String) async -> String? {
        await transact(WatchCommand(action: .sell, itemID: itemID), fallback: "Vente refusée.")
    }

    /// Effectue une renaissance après confirmation.
    ///
    /// - Returns: Un message d'erreur, `nil` en cas de succès.
    func rebirth() async -> String? {
        await transact(WatchCommand(action: .rebirth), fallback: "Renaissance impossible.")
    }

    /// Recharge les agrégats communautaires.
    ///
    /// - Returns: Un message d'erreur, `nil` en cas de succès.
    func refreshCommunity() async -> String? {
        await transact(WatchCommand(action: .refreshStats), fallback: "Agrégats indisponibles.")
    }

    /// Demande les compteurs d'un item.
    ///
    /// - Parameter itemID: Identifiant de l'item.
    /// - Returns: Les compteurs locaux et mondiaux, `nil` en cas d'échec.
    func itemStats(_ itemID: String) async -> WatchItemStats? {
        let reply = await send(WatchCommand(action: .item, itemID: itemID))
        guard reply.kind == .item, let item = reply.item else {
            recordFailure(reply, fallback: "Statistiques indisponibles.")
            return nil
        }
        lastErrorValue = nil
        return item
    }

    private func transact(_ command: WatchCommand, fallback: String) async -> String? {
        let reply = await send(command)
        guard reply.kind == .state else {
            recordFailure(reply, fallback: fallback)
            return lastErrorValue
        }
        lastErrorValue = nil
        return nil
    }

    private func recordFailure(_ reply: WatchReply, fallback: String) {
        lastErrorValue = reply.message ?? fallback
    }

    private func send(_ command: WatchCommand) async -> WatchReply {
        if mode == .local {
            return local(command)
        }
        guard !isLocked else {
            return .failure("Ouvre l'iPhone et connecte-toi.", commandID: command.id)
        }
        guard canPlay else {
            return .failure("Ouvre l'iPhone pour jouer.", commandID: command.id)
        }
        guard let data = WatchWire.encode(.command(command)) else {
            return .failure("Commande invalide.", commandID: command.id)
        }
        return await withCheckedContinuation { continuation in
            pending[command.id] = continuation
            timeoutTasks[command.id] = Task { [weak self] in
                do {
                    try await Task.sleep(for: Self.replyTimeout)
                } catch {
                    return
                }
                self?.fail(commandID: command.id, message: "Pas de réponse de l'iPhone.")
            }
            WCSession.default.sendMessageData(data, replyHandler: nil) { [weak self] _ in
                Task { @MainActor in self?.fail(commandID: command.id, message: "Envoi impossible.") }
            }
        }
    }

    private func fail(commandID: UUID, message: String) {
        guard let continuation = pending.removeValue(forKey: commandID) else { return }
        timeoutTasks.removeValue(forKey: commandID)?.cancel()
        continuation.resume(returning: .failure(message, commandID: commandID))
    }

    private func failAllPending(_ message: String) {
        for id in Array(pending.keys) {
            fail(commandID: id, message: message)
        }
    }

    private func handle(_ packet: WatchPacket) {
        switch packet.kind {
        case .state:
            guard let state = packet.state else { return }
            apply(state)
        case .reply:
            guard let reply = packet.reply else { return }
            if let state = reply.state {
                apply(state)
            }
            if let opened = reply.opened {
                apply(opened.state)
            }
            guard let continuation = pending.removeValue(forKey: reply.commandID) else { return }
            timeoutTasks.removeValue(forKey: reply.commandID)?.cancel()
            continuation.resume(returning: reply)
        case .lock:
            lock()
        case .command:
            break
        }
    }

    private func apply(_ state: WatchState) {
        self.state = state
        setLocked(false)
        pendingState = state
        applyPending()
        updateComplication()
    }

    private func lock() {
        state = nil
        pendingState = nil
        setLocked(true)
        failAllPending("Compte requis sur l'iPhone.")
        _ = store.applyRemote(.empty())
        updateComplication()
    }

    private func activationChanged(_ active: Bool) {
        isActivated = active
        isReachable = active && WCSession.default.isReachable
        guard active else {
            failAllPending("iPhone non joignable.")
            return
        }
        requestState()
    }

    private func reachabilityChanged(_ reachable: Bool) {
        isReachable = reachable
        guard reachable else {
            failAllPending("iPhone non joignable.")
            return
        }
        requestState()
    }

    private func requestState() {
        guard isActivated, isReachable else { return }
        Task { [weak self] in
            _ = await self?.send(WatchCommand(action: .state))
        }
    }

    private func setLocked(_ locked: Bool) {
        isLocked = locked
        UserDefaults.standard.set(locked, forKey: Self.lockedKey)
    }

    private func updateComplication() {
        guard !isLocked else {
            ComplicationStore.clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        ComplicationStore.save(
            ComplicationState(
                progress: store.progress,
                dust: store.dust,
                title: store.explorerTitle.displayName,
                nextTitle: store.nextExplorerTitle?.displayName,
                updatedAt: .now
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func local(_ command: WatchCommand) -> WatchReply {
        switch command.action {
        case .state:
            return .state(localState(), commandID: command.id)
        case .plan:
            guard let plan = store.planOpening() else {
                return .failure("Catalogue indisponible.", commandID: command.id)
            }
            return .plan(WatchPlan(booster: plan.booster, kind: plan.kind), commandID: command.id)
        case .open:
            guard let booster = command.booster, let kind = command.kind else {
                return .failure("Plan invalide.", commandID: command.id)
            }
            let results = store.open(booster, kind: kind)
            guard !results.isEmpty else {
                return .failure("Ouverture impossible.", commandID: command.id)
            }
            let cards = results.map { WatchDraw(itemID: $0.item.id, dust: $0.dust, isNew: $0.isNew) }
            let opened = WatchOpenResult(
                plan: WatchPlan(booster: booster, kind: kind),
                cards: cards,
                state: localState()
            )
            self.state = opened.state
            updateComplication()
            return .opened(opened, commandID: command.id)
        case .close:
            store.endOpening()
            return .state(localState(), commandID: command.id)
        case .buy:
            guard let id = command.itemID, let item = store.catalog.first(where: { $0.id == id }) else {
                return .failure("Item inconnu.", commandID: command.id)
            }
            do {
                try store.buy(item)
                let snapshot = localState()
                state = snapshot
                updateComplication()
                return .state(snapshot, commandID: command.id)
            } catch {
                return .failure("Achat refusé.", commandID: command.id)
            }
        case .sell:
            guard let id = command.itemID else {
                return .failure("Item inconnu.", commandID: command.id)
            }
            do {
                try store.sell(id)
                let snapshot = localState()
                state = snapshot
                updateComplication()
                return .state(snapshot, commandID: command.id)
            } catch {
                return .failure("Vente refusée.", commandID: command.id)
            }
        case .rebirth:
            do {
                try store.rebirth()
                let snapshot = localState()
                state = snapshot
                updateComplication()
                return .state(snapshot, commandID: command.id)
            } catch {
                return .failure("Renaissance impossible.", commandID: command.id)
            }
        case .refreshStats:
            state = localState()
            return .state(state ?? localState(), commandID: command.id)
        case .item:
            guard let id = command.itemID, let item = store.catalog.first(where: { $0.id == id }) else {
                return .failure("Item inconnu.", commandID: command.id)
            }
            return .item(
                WatchItemStats(
                    localPulls: store.pullCount(for: item),
                    globalPulls: 0,
                    globalTrades: 0,
                    updatedAt: .now
                ),
                commandID: command.id
            )
        }
    }

    private func localState() -> WatchState {
        WatchState(
            snapshot: store.progressSnapshot(),
            totalOpened: store.totalOpened,
            globalPulls: 0,
            globalTrades: 0,
            globalLoaded: false
        )
    }
}
