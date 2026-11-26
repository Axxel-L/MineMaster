import Foundation
import WatchConnectivity

/// Relais `WCSession` sans état, partagé par l'iPhone et la montre.
///
/// Les rappels système arrivent sur une file série non principale : le relais
/// décode la charge utile en valeur `Sendable`, puis la transmet à l'appelant.
nonisolated final class WatchSessionRelay: NSObject, WCSessionDelegate {
    private let onPacket: @Sendable (WatchPacket) -> Void
    private let onReachability: @Sendable (Bool) -> Void
    private let onActivation: @Sendable (Bool) -> Void
    private let onReactivate: @Sendable () -> Void

    /// Crée un relais relié aux callbacks de l'application.
    ///
    /// - Parameters:
    ///   - onPacket: Paquet validé reçu du pair.
    ///   - onReachability: Nouvel état de joignabilité.
    ///   - onActivation: Résultat de l'activation.
    ///   - onReactivate: Demande de réactivation après un changement de montre.
    init(
        onPacket: @escaping @Sendable (WatchPacket) -> Void,
        onReachability: @escaping @Sendable (Bool) -> Void,
        onActivation: @escaping @Sendable (Bool) -> Void,
        onReactivate: @escaping @Sendable () -> Void
    ) {
        self.onPacket = onPacket
        self.onReachability = onReachability
        self.onActivation = onActivation
        self.onReactivate = onReactivate
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        onActivation(activationState == .activated)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachability(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let packet = WatchWire.decode(context: applicationContext) {
            onPacket(packet)
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        if let packet = WatchWire.decode(messageData) {
            onPacket(packet)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        onReactivate()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        onReactivate()
    }
    #endif
}

/// Émission bornée des paquets `WCSession`.
nonisolated enum WatchTransport {
    /// Publie le dernier état dans le contexte applicatif.
    ///
    /// - Parameter packet: Paquet à publier.
    /// - Throws: L'erreur système si le contexte est refusé.
    static func publish(_ packet: WatchPacket) throws {
        guard WCSession.isSupported(),
              let data = WatchWire.encode(packet) else {
            throw AppError.invalidResponse
        }
        try WCSession.default.updateApplicationContext([WatchWire.key: data])
    }

    /// Envoie un paquet immédiat lorsque le pair est joignable.
    ///
    /// - Parameters:
    ///   - packet: Paquet à envoyer.
    ///   - onError: Appelé avec un message sûr si l'envoi échoue.
    static func send(_ packet: WatchPacket, onError: @escaping @Sendable (String) -> Void) {
        guard WCSession.isSupported() else {
            onError("WatchConnectivity indisponible.")
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            onError("iPhone non joignable.")
            return
        }
        guard let data = WatchWire.encode(packet) else {
            onError("Charge utile trop grande.")
            return
        }
        session.sendMessageData(data, replyHandler: nil) { error in
            onError(error.localizedDescription)
        }
    }
}
