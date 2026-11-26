import Foundation

/// Action demandée par la montre à l'iPhone.
nonisolated enum WatchAction: String, Codable, Sendable {
    case plan
    case open
    case close
    case buy
    case sell
    case rebirth
    case refreshStats
    case item
    case state
}

/// Commande envoyée par la montre, identifiée pour rester idempotente.
nonisolated struct WatchCommand: Codable, Sendable, Equatable {
    let id: UUID
    let action: WatchAction
    let itemID: String?
    let boosterRaw: String?
    let kindRaw: String?

    /// Construit une commande sans paramètre.
    ///
    /// - Parameter action: Action à exécuter.
    init(action: WatchAction) {
        id = UUID()
        self.action = action
        itemID = nil
        boosterRaw = nil
        kindRaw = nil
    }

    /// Construit une commande ciblant un item.
    ///
    /// - Parameters:
    ///   - action: Action à exécuter.
    ///   - itemID: Identifiant de l'item ciblé.
    init(action: WatchAction, itemID: String) {
        id = UUID()
        self.action = action
        self.itemID = itemID
        boosterRaw = nil
        kindRaw = nil
    }

    /// Construit une commande d'ouverture liée à un plan.
    ///
    /// - Parameters:
    ///   - action: Action à exécuter.
    ///   - booster: Booster planifié.
    ///   - kind: Type de contenu planifié.
    init(action: WatchAction, booster: Booster, kind: BoosterKind) {
        id = UUID()
        self.action = action
        itemID = nil
        boosterRaw = booster.rawValue
        kindRaw = kind.rawValue
    }

    /// Booster décodé, `nil` si la valeur reçue est invalide.
    var booster: Booster? {
        boosterRaw.flatMap(Booster.init(rawValue:))
    }

    /// Type de contenu décodé, `nil` si la valeur reçue est invalide.
    var kind: BoosterKind? {
        kindRaw.flatMap(BoosterKind.init(rawValue:))
    }

    /// Décode une commande en refusant les identifiants non conformes.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si une valeur est invalide.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        action = try container.decode(WatchAction.self, forKey: .action)
        itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        boosterRaw = try container.decodeIfPresent(String.self, forKey: .boosterRaw)
        kindRaw = try container.decodeIfPresent(String.self, forKey: .kindRaw)
        if let itemID, !ProgressSnapshot.isSafeIdentifier(itemID) {
            throw DecodingError.dataCorruptedError(forKey: .itemID, in: container, debugDescription: "Identifiant invalide")
        }
        if let boosterRaw, Booster(rawValue: boosterRaw) == nil {
            throw DecodingError.dataCorruptedError(forKey: .boosterRaw, in: container, debugDescription: "Booster invalide")
        }
        if let kindRaw, BoosterKind(rawValue: kindRaw) == nil {
            throw DecodingError.dataCorruptedError(forKey: .kindRaw, in: container, debugDescription: "Type invalide")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case action
        case itemID
        case boosterRaw
        case kindRaw
    }
}

/// Plan d'ouverture transmis par l'iPhone.
nonisolated struct WatchPlan: Codable, Sendable, Equatable {
    let boosterRaw: String
    let kindRaw: String

    /// Construit un plan sérialisable.
    ///
    /// - Parameters:
    ///   - booster: Booster planifié.
    ///   - kind: Type de contenu planifié.
    init(booster: Booster, kind: BoosterKind) {
        boosterRaw = booster.rawValue
        kindRaw = kind.rawValue
    }

    /// Booster décodé, `nil` si la valeur reçue est invalide.
    var booster: Booster? {
        Booster(rawValue: boosterRaw)
    }

    /// Type de contenu décodé, `nil` si la valeur reçue est invalide.
    var kind: BoosterKind? {
        BoosterKind(rawValue: kindRaw)
    }

    /// Décode un plan en refusant les valeurs hors énumération.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si une valeur est invalide.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boosterRaw = try container.decode(String.self, forKey: .boosterRaw)
        kindRaw = try container.decode(String.self, forKey: .kindRaw)
        if Booster(rawValue: boosterRaw) == nil {
            throw DecodingError.dataCorruptedError(forKey: .boosterRaw, in: container, debugDescription: "Booster invalide")
        }
        if BoosterKind(rawValue: kindRaw) == nil {
            throw DecodingError.dataCorruptedError(forKey: .kindRaw, in: container, debugDescription: "Type invalide")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case boosterRaw
        case kindRaw
    }
}

/// Carte tirée, réduite à ce que la montre doit afficher.
nonisolated struct WatchDraw: Codable, Sendable, Equatable {
    let itemID: String
    let dust: Int
    let isNew: Bool

    /// Construit un tirage en bornant la poussière.
    ///
    /// - Parameters:
    ///   - itemID: Identifiant tiré.
    ///   - dust: Poussière gagnée.
    ///   - isNew: Indique un item découvert.
    init(itemID: String, dust: Int, isNew: Bool) {
        self.itemID = itemID
        self.dust = ProgressSnapshot.clamp(dust, maximum: ProgressSnapshot.maximumCounter)
        self.isNew = isNew
    }

    /// Décode un tirage en validant l'identifiant et les bornes.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si l'identifiant est invalide.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .itemID)
        guard ProgressSnapshot.isSafeIdentifier(id) else {
            throw DecodingError.dataCorruptedError(forKey: .itemID, in: container, debugDescription: "Identifiant invalide")
        }
        self.init(
            itemID: id,
            dust: try container.decode(Int.self, forKey: .dust),
            isNew: try container.decode(Bool.self, forKey: .isNew)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case itemID
        case dust
        case isNew
    }
}

/// Résultat complet d'une ouverture demandée par la montre.
nonisolated struct WatchOpenResult: Codable, Sendable, Equatable {
    let plan: WatchPlan
    let cards: [WatchDraw]
    let state: WatchState
}

/// Compteurs d'un item, locaux et communautaires.
nonisolated struct WatchItemStats: Codable, Sendable, Equatable {
    let localPulls: Int
    let globalPulls: Int
    let globalTrades: Int
    let updatedAt: Date

    /// Construit un agrégat en bornant les compteurs.
    ///
    /// - Parameters:
    ///   - localPulls: Tirages du compte.
    ///   - globalPulls: Tirages mondiaux.
    ///   - globalTrades: Échanges mondiaux.
    ///   - updatedAt: Date de référence.
    init(localPulls: Int, globalPulls: Int, globalTrades: Int, updatedAt: Date) {
        self.localPulls = ProgressSnapshot.clamp(localPulls, maximum: ProgressSnapshot.maximumCounter)
        self.globalPulls = ProgressSnapshot.clamp(globalPulls, maximum: ProgressSnapshot.maximumCounter)
        self.globalTrades = ProgressSnapshot.clamp(globalTrades, maximum: ProgressSnapshot.maximumCounter)
        self.updatedAt = updatedAt
    }

    /// Décode des compteurs en bornant toutes les valeurs.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si un champ manque.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            localPulls: try container.decode(Int.self, forKey: .localPulls),
            globalPulls: try container.decode(Int.self, forKey: .globalPulls),
            globalTrades: try container.decode(Int.self, forKey: .globalTrades),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case localPulls
        case globalPulls
        case globalTrades
        case updatedAt
    }
}

/// État complet de la progression affiché par la montre.
nonisolated struct WatchState: Codable, Sendable, Equatable {
    let snapshot: ProgressSnapshot
    let totalOpened: Int
    let globalPulls: Int
    let globalTrades: Int
    let globalLoaded: Bool

    /// Construit un état en bornant les compteurs.
    ///
    /// - Parameters:
    ///   - snapshot: Progression du compte.
    ///   - totalOpened: Nombre d'ouvertures cumulées.
    ///   - globalPulls: Tirages mondiaux connus.
    ///   - globalTrades: Échanges mondiaux connus.
    ///   - globalLoaded: Indique que les agrégats mondiaux ont été lus.
    init(
        snapshot: ProgressSnapshot,
        totalOpened: Int,
        globalPulls: Int,
        globalTrades: Int,
        globalLoaded: Bool
    ) {
        self.snapshot = snapshot
        self.totalOpened = ProgressSnapshot.clamp(totalOpened, maximum: ProgressSnapshot.maximumCounter)
        self.globalPulls = ProgressSnapshot.clamp(globalPulls, maximum: ProgressSnapshot.maximumCounter)
        self.globalTrades = ProgressSnapshot.clamp(globalTrades, maximum: ProgressSnapshot.maximumCounter)
        self.globalLoaded = globalLoaded
    }

    /// Décode un état en bornant tous les compteurs.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si un champ manque.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            snapshot: try container.decode(ProgressSnapshot.self, forKey: .snapshot),
            totalOpened: try container.decode(Int.self, forKey: .totalOpened),
            globalPulls: try container.decode(Int.self, forKey: .globalPulls),
            globalTrades: try container.decode(Int.self, forKey: .globalTrades),
            globalLoaded: try container.decode(Bool.self, forKey: .globalLoaded)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case snapshot
        case totalOpened
        case globalPulls
        case globalTrades
        case globalLoaded
    }
}

/// Réponse de l'iPhone à une commande de la montre.
nonisolated struct WatchReply: Codable, Sendable, Equatable {
    /// Nature du résultat transporté.
    enum Kind: String, Codable, Sendable {
        case state
        case plan
        case opened
        case item
        case failure
    }

    let commandID: UUID
    let kind: Kind
    let state: WatchState?
    let plan: WatchPlan?
    let opened: WatchOpenResult?
    let item: WatchItemStats?
    let message: String?

    /// Réponse portant un état complet.
    ///
    /// - Parameters:
    ///   - commandID: Commande d'origine.
    ///   - state: État courant.
    /// - Returns: La réponse sérialisable.
    static func state(_ state: WatchState, commandID: UUID) -> WatchReply {
        WatchReply(
            commandID: commandID,
            kind: .state,
            state: state,
            plan: nil,
            opened: nil,
            item: nil,
            message: nil
        )
    }

    /// Réponse portant un plan d'ouverture.
    ///
    /// - Parameters:
    ///   - commandID: Commande d'origine.
    ///   - plan: Plan préparé.
    /// - Returns: La réponse sérialisable.
    static func plan(_ plan: WatchPlan, commandID: UUID) -> WatchReply {
        WatchReply(
            commandID: commandID,
            kind: .plan,
            state: nil,
            plan: plan,
            opened: nil,
            item: nil,
            message: nil
        )
    }

    /// Réponse portant une ouverture complète.
    ///
    /// - Parameters:
    ///   - commandID: Commande d'origine.
    ///   - opened: Résultat de l'ouverture.
    /// - Returns: La réponse sérialisable.
    static func opened(_ opened: WatchOpenResult, commandID: UUID) -> WatchReply {
        WatchReply(
            commandID: commandID,
            kind: .opened,
            state: nil,
            plan: nil,
            opened: opened,
            item: nil,
            message: nil
        )
    }

    /// Réponse portant les compteurs d'un item.
    ///
    /// - Parameters:
    ///   - commandID: Commande d'origine.
    ///   - item: Compteurs de l'item.
    /// - Returns: La réponse sérialisable.
    static func item(_ item: WatchItemStats, commandID: UUID) -> WatchReply {
        WatchReply(
            commandID: commandID,
            kind: .item,
            state: nil,
            plan: nil,
            opened: nil,
            item: item,
            message: nil
        )
    }

    /// Réponse d'échec lisible par la montre.
    ///
    /// - Parameters:
    ///   - commandID: Commande d'origine.
    ///   - message: Message affichable, tronqué à 120 caractères.
    /// - Returns: La réponse sérialisable.
    static func failure(_ message: String, commandID: UUID) -> WatchReply {
        WatchReply(
            commandID: commandID,
            kind: .failure,
            state: nil,
            plan: nil,
            opened: nil,
            item: nil,
            message: String(message.prefix(120))
        )
    }

    private init(
        commandID: UUID,
        kind: Kind,
        state: WatchState?,
        plan: WatchPlan?,
        opened: WatchOpenResult?,
        item: WatchItemStats?,
        message: String?
    ) {
        self.commandID = commandID
        self.kind = kind
        self.state = state
        self.plan = plan
        self.opened = opened
        self.item = item
        self.message = message
    }
}

/// Paquet échangé entre l'iPhone et la montre.
nonisolated struct WatchPacket: Codable, Sendable {
    /// Nature du paquet.
    enum Kind: String, Codable, Sendable {
        case state
        case command
        case reply
        case lock
    }

    let kind: Kind
    let state: WatchState?
    let command: WatchCommand?
    let reply: WatchReply?

    /// Construit un paquet sans charge utile.
    ///
    /// - Parameter kind: Nature du paquet.
    private init(kind: Kind) {
        self.kind = kind
        state = nil
        command = nil
        reply = nil
    }

    /// Paquet de synchronisation montante.
    ///
    /// - Parameter state: État courant.
    /// - Returns: Le paquet sérialisable.
    static func state(_ state: WatchState) -> WatchPacket {
        WatchPacket(kind: .state, state: state, command: nil, reply: nil)
    }

    /// Paquet de commande.
    ///
    /// - Parameter command: Commande à exécuter.
    /// - Returns: Le paquet sérialisable.
    static func command(_ command: WatchCommand) -> WatchPacket {
        WatchPacket(kind: .command, state: nil, command: command, reply: nil)
    }

    /// Paquet de réponse.
    ///
    /// - Parameter reply: Réponse à transmettre.
    /// - Returns: Le paquet sérialisable.
    static func reply(_ reply: WatchReply) -> WatchPacket {
        WatchPacket(kind: .reply, state: nil, command: nil, reply: reply)
    }

    /// Verrouille la montre après une déconnexion.
    static var lock: WatchPacket {
        WatchPacket(kind: .lock)
    }

    private init(kind: Kind, state: WatchState?, command: WatchCommand?, reply: WatchReply?) {
        self.kind = kind
        self.state = state
        self.command = command
        self.reply = reply
    }
}

/// Encodage borné des paquets échangés avec la montre.
nonisolated enum WatchWire {
    /// Clé du dictionnaire de contexte applicatif.
    static let key = "payload"

    /// Taille maximale d'un paquet, sous la limite de `updateApplicationContext`.
    static let maximumBytes = 60_000

    /// Taille maximale d'une commande.
    static let maximumCommandBytes = 8_192

    /// Sérialise un paquet.
    ///
    /// - Parameter packet: Paquet à envoyer.
    /// - Returns: Les données prêtes, `nil` si le paquet dépasse la borne.
    static func encode(_ packet: WatchPacket) -> Data? {
        do {
            let data = try JSONEncoder().encode(packet)
            return data.count <= maximumBytes ? data : nil
        } catch {
            return nil
        }
    }

    /// Décode un paquet reçu.
    ///
    /// - Parameter data: Charge utile brute.
    /// - Returns: Le paquet validé, `nil` si la taille ou le format est invalide.
    static func decode(_ data: Data) -> WatchPacket? {
        guard !data.isEmpty, data.count <= maximumBytes else { return nil }
        do {
            let packet = try JSONDecoder().decode(WatchPacket.self, from: data)
            switch packet.kind {
            case .command:
                guard let command = packet.command else { return nil }
                return data.count <= maximumCommandBytes ? WatchPacket.command(command) : nil
            case .reply:
                guard let reply = packet.reply else { return nil }
                return WatchPacket.reply(reply)
            case .state:
                guard let state = packet.state else { return nil }
                return WatchPacket.state(state)
            case .lock:
                return WatchPacket.lock
            }
        } catch {
            return nil
        }
    }

    /// Décode un contexte applicatif.
    ///
    /// - Parameter context: Dictionnaire reçu de `WCSession`.
    /// - Returns: Le paquet validé, `nil` si la charge utile manque.
    static func decode(context: [String: Any]) -> WatchPacket? {
        guard let data = context[key] as? Data else { return nil }
        return decode(data)
    }
}
