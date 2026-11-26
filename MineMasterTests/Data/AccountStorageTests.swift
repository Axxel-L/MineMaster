import Foundation
import Testing
@testable import MineMaster

@Suite("Stockage par compte")
struct AccountStorageTests {
    @Test("Un identifiant Firebase standard est accepté")
    func acceptsFirebaseIdentifier() {
        #expect(AppPersistence.isValidAccountID("kd8Jf2LmQ0aXy7Tb1Nc3"))
        #expect(AppPersistence.isValidAccountID("abc-DEF_123"))
    }

    @Test("Un identifiant contenant un séparateur de chemin est refusé")
    func rejectsPathCharacters() {
        #expect(!AppPersistence.isValidAccountID("../player"))
        #expect(!AppPersistence.isValidAccountID("a/b"))
        #expect(!AppPersistence.isValidAccountID("a.b"))
        #expect(!AppPersistence.isValidAccountID("a b"))
        #expect(!AppPersistence.isValidAccountID(""))
        #expect(!AppPersistence.isValidAccountID(String(repeating: "a", count: 129)))
    }

    @Test("Chaque compte obtient un magasin distinct dans le dossier applicatif")
    func buildsDistinctStores() throws {
        let first = try #require(AppPersistence.storeURL(for: "accountA"))
        let second = try #require(AppPersistence.storeURL(for: "accountB"))

        #expect(first != second)
        #expect(first.deletingLastPathComponent() == AppPersistence.accountDirectory)
        #expect(first.lastPathComponent == "account-accountA.store")
    }

    @Test("Un identifiant invalide ne produit aucune URL de magasin")
    func refusesInvalidIdentifier() {
        #expect(AppPersistence.storeURL(for: "../../etc/passwd") == nil)
    }
}
