import Foundation
import SwiftData

/// Schéma SwiftData et stockage local partitionné par compte.
///
/// Chaque compte Firebase possède son propre fichier de magasin. Un compte ne
/// peut donc jamais lire la progression d'un autre, même après une déconnexion
/// ou un changement de session.
enum AppPersistence {
    /// Ensemble des modèles persistés par l'application.
    nonisolated static let schema = Schema([
        CatalogItemRecord.self,
        CollectionRecord.self,
        PlayerRecord.self,
        OpeningRecord.self,
        MarketListingRecord.self
    ])

    /// Dossier racine des magasins par compte, dans `Application Support`.
    nonisolated static var accountDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "MineMaster/Accounts", directoryHint: .isDirectory)
    }

    /// Valide l'identifiant de compte avant tout usage dans un chemin de fichier.
    ///
    /// - Parameter accountID: Identifiant fourni par Firebase Auth.
    /// - Returns: `true` si l'identifiant ne contient que des caractères sûrs.
    nonisolated static func isValidAccountID(_ accountID: String) -> Bool {
        guard (1...128).contains(accountID.count) else { return false }
        return accountID.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == "_")
        }
    }

    /// URL du magasin d'un compte, dans le dossier applicatif uniquement.
    ///
    /// - Parameter accountID: Identifiant fourni par Firebase Auth.
    /// - Returns: L'URL du fichier, ou `nil` si l'identifiant est invalide.
    nonisolated static func storeURL(for accountID: String) -> URL? {
        guard isValidAccountID(accountID) else { return nil }
        return accountDirectory.appending(path: "account-\(accountID).store")
    }

    /// Ouvre le magasin d'un compte, en le créant au premier lancement.
    ///
    /// - Parameter accountID: Identifiant fourni par Firebase Auth.
    /// - Throws: `AppError.storageUnavailable` si l'identifiant est invalide,
    ///   si le dossier ne peut pas être créé ou si SwiftData refuse le fichier.
    /// - Returns: Le conteneur SwiftData du compte.
    nonisolated static func container(for accountID: String) throws -> ModelContainer {
        guard let url = storeURL(for: accountID) else { throw AppError.storageUnavailable }
        do {
            try FileManager.default.createDirectory(at: accountDirectory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(schema: schema, url: url)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw AppError.storageUnavailable
        }
    }

    /// Supprime le magasin local d'un compte pour repartir d'un fichier sain.
    ///
    /// Le document Firestore reste intact : la progression est restaurée à la
    /// prochaine ouverture si le compte en possède une.
    ///
    /// - Parameter accountID: Identifiant fourni par Firebase Auth.
    /// - Throws: `AppError.storageUnavailable` si l'identifiant est invalide.
    nonisolated static func resetStore(for accountID: String) throws {
        guard let url = storeURL(for: accountID) else { throw AppError.storageUnavailable }
        let manager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? manager.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
