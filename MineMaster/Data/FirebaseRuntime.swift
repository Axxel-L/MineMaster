import FirebaseCore
import Foundation
import Synchronization

/// Configuration Firebase et capacités réellement disponibles sur l'appareil.
///
/// La configuration lit `GoogleService-Info.plist` embarqué. Aucune valeur
/// sensible n'est journalisée : la clé API Firebase est publique par conception,
/// le reste du fichier ne doit jamais finir dans les logs.
enum FirebaseRuntime {
    /// Nom du fichier de configuration téléchargé depuis la console Firebase.
    nonisolated static let configurationFile = "GoogleService-Info"

    /// Indique si le fichier de configuration est présent dans le bundle.
    nonisolated static var hasConfigurationFile: Bool {
        Bundle.main.url(forResource: configurationFile, withExtension: "plist") != nil
    }

    /// Identifiant OAuth client Google, absent tant que le fournisseur n'est pas activé.
    nonisolated static var googleClientID: String? {
        guard let plist = configurationPlist() else { return nil }
        let clientID = plist["CLIENT_ID"] as? String
        return clientID?.isEmpty == false ? clientID : nil
    }

    /// URL scheme inversé attendu pour le retour OAuth de Google.
    nonisolated static var googleURLScheme: String? {
        guard let clientID = googleClientID else { return nil }
        return clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    /// Indique si l'URL scheme Google est déclaré dans l'Info.plist du bundle.
    nonisolated static var hasRegisteredGoogleURLScheme: Bool {
        guard let scheme = googleURLScheme,
              let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }
        return types.contains { type in
            (type["CFBundleURLSchemes"] as? [String])?.contains(scheme) == true
        }
    }

    /// Indique si le bouton Google peut réellement aboutir.
    nonisolated static var isGoogleSignInReady: Bool {
        googleClientID != nil && hasRegisteredGoogleURLScheme
    }

    private nonisolated static let configurationState = Mutex(false)

    /// Configure Firebase une seule fois.
    ///
    /// Appelée hors du `MainActor` pour ne pas retarder la première image. Le
    /// verrou évite un double `configure()` si la vue racine se réaffiche.
    ///
    /// - Returns: `true` si Firebase est prêt, `false` si le fichier de
    ///   configuration manque ou si l'initialisation échoue.
    nonisolated static func configure() -> Bool {
        configurationState.withLock { configured in
            if configured { return true }
            guard hasConfigurationFile else { return false }
            FirebaseApp.configure()
            let ready = FirebaseApp.app() != nil
            configured = ready
            return ready
        }
    }

    private nonisolated static func configurationPlist() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: configurationFile, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}
