import Foundation
import Observation
import WatchConnectivity

/// Pont iPhone vers la montre, unique propriétaire de la progression montrée.
///
/// Le pont publie un état borné, exécute les commandes de la montre contre le
/// magasin authentifié et ne diffuse jamais de progression sans compte actif.
@Observable
@MainActor
final class WatchBridge {
    private var relay: WatchSessionRelay?
    private var router: WatchCommandRouter?
    private var pushTask: Task<Void, Never>?
    private var isActive = true

    private(set) var isActivated = false
    private(set) var isReachable = false
    private(set) var lastError: AppError?

    /// Active la session `WCSession` une seule fois.
    func start() {
        guard relay == nil, WCSession.isSupported() else { return }
        let relay = WatchSessionRelay(
            onPacket: { [weak self] packet in
                Task { @MainActor in await self?.handle(packet) }
            },
            onReachability: { [weak self] reachable in
                Task { @MainActor in self?.reachabilityChanged(reachable) }
            },
            onActivation: { [weak self] active in
                Task { @MainActor in self?.activationChanged(active) }
            },
            onReactivate: { [weak self] in
                Task { @MainActor in self?.reactivate() }
            }
        )
        self.relay = relay
        WCSession.default.delegate = relay
        WCSession.default.activate()
    }

    /// Branche le magasin d'un compte authentifié.
    ///
    /// - Parameters:
    ///   - store: Magasin local du compte.
    ///   - stats: Agrégats communautaires du compte.
    func attach(store: GameStore, stats: GlobalStatsSync) {
        isActive = true
        router = WatchCommandRouter(store: store, stats: stats)
        pushNow()
    }

    /// Retire le compte courant et verrouille la montre.
    func lock() {
        router = nil
        pushTask?.cancel()
        pushTask = nil
        pushNow()
    }

    /// Programme une publication regroupée après une écriture locale.
    func schedulePush() {
        guard isActive else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.pushNow()
        }
    }

    /// Publie immédiatement l'état courant.
    func pushNow() {
        guard isActive, isActivated else { return }
        let packet: WatchPacket = if let router {
            .state(router.state())
        } else {
            .lock
        }
        do {
            try WatchTransport.publish(packet)
            lastError = nil
        } catch {
            lastError = .invalidResponse
        }
        guard isReachable, WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else {
            return
        }
        WatchTransport.send(packet) { [weak self] _ in
            Task { @MainActor in self?.lastError = .offline }
        }
    }

    private func handle(_ packet: WatchPacket) async {
        guard isActive, let router else { return }
        switch packet.kind {
        case .command:
            guard let command = packet.command else { return }
            let reply = await router.handle(command)
            if reply.kind == .state || reply.kind == .opened {
                schedulePush()
            }
            guard isReachable else { return }
            WatchTransport.send(.reply(reply)) { [weak self] _ in
                Task { @MainActor in self?.lastError = .offline }
            }
        case .reply, .state, .lock:
            break
        }
    }

    private func activationChanged(_ active: Bool) {
        isActivated = active
        if active {
            pushNow()
        }
    }

    private func reachabilityChanged(_ reachable: Bool) {
        isReachable = reachable
        if reachable {
            pushNow()
        }
    }

    private func reactivate() {
        WCSession.default.activate()
    }
}
