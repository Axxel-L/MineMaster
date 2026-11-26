import Foundation

/// Données minimales partagées avec la complication.
nonisolated struct ComplicationState: Codable, Sendable, Equatable {
    /// Plafond de poussière aligné sur les règles Firestore.
    static let maximumDust = 1_000_000_000

    let progress: Double
    let dust: Int
    let title: String
    let nextTitle: String?
    let updatedAt: Date

    /// Construit un état borné pour la complication.
    ///
    /// - Parameters:
    ///   - progress: Progression entre `0` et `1`.
    ///   - dust: Poussière du compte.
    ///   - title: Titre d'explorateur courant.
    ///   - nextTitle: Prochain titre, `nil` au dernier palier.
    ///   - updatedAt: Date de dernière synchronisation.
    init(progress: Double, dust: Int, title: String, nextTitle: String? = nil, updatedAt: Date) {
        self.progress = min(max(progress.isFinite ? progress : 0, 0), 1)
        self.dust = min(max(dust, 0), Self.maximumDust)
        self.title = String(title.prefix(40))
        self.nextTitle = nextTitle.map { String($0.prefix(40)) }
        self.updatedAt = updatedAt
    }

    /// Décode un état en bornant toutes les valeurs.
    ///
    /// - Parameter decoder: Décodeur du flux reçu.
    /// - Throws: Une erreur de décodage si un champ manque.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            progress: try container.decode(Double.self, forKey: .progress),
            dust: try container.decode(Int.self, forKey: .dust),
            title: try container.decode(String.self, forKey: .title),
            nextTitle: try container.decodeIfPresent(String.self, forKey: .nextTitle),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case progress
        case dust
        case title
        case nextTitle
        case updatedAt
    }
}

/// Accès au conteneur partagé entre la montre et sa complication.
nonisolated enum ComplicationStore {
    /// Identifiant du groupe d'applications.
    static let suiteName = "group.com.minemaster.iut-st-die"

    /// Clé de l'état partagé.
    static let key = "complication.state"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Lit le dernier état partagé.
    ///
    /// - Returns: L'état validé, `nil` si le groupe ou la charge utile manque.
    static func load() -> ComplicationState? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(ComplicationState.self, from: data)
        } catch {
            return nil
        }
    }

    /// Écrit un état borné pour la complication.
    ///
    /// - Parameter state: État à partager.
    static func save(_ state: ComplicationState) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
        } catch {
            return
        }
    }

    /// Efface l'état partagé.
    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
