import Foundation
import Testing
@testable import MineMaster

/// Vérifie qu'une opération asynchrone échoue avec l'erreur applicative attendue.
///
/// - Parameters:
///   - expected: Erreur attendue.
///   - operation: Opération à exécuter.
/// - Authors: Axel L.
func expectAppError(
    _ expected: AppError,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Erreur attendue absente: \(expected)")
    } catch let error as AppError {
        #expect(error == expected)
    } catch {
        Issue.record("Erreur inattendue: \(error)")
    }
}
