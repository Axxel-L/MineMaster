import Testing
@testable import MineMaster

@Suite("Bornage des opérations Firestore")
struct FirestoreTaskTests {
    @Test("Une opération rapide retourne sa valeur")
    func returnsValue() async throws {
        let value = try await FirestoreTask.bounded { 42 }

        #expect(value == 42)
    }

    @Test("Une erreur Firestore est propagée")
    func propagatesError() async {
        do {
            let _: Int = try await FirestoreTask.bounded { throw AppError.offline }
            Issue.record("Une erreur était attendue.")
        } catch let error as AppError {
            #expect(error == .offline)
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    @Test("Une opération bloquée expire sans attendre sa réponse")
    func timesOut() async {
        do {
            let _: Int = try await FirestoreTask.bounded(seconds: 0.05) {
                await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
                return 0
            }
            Issue.record("Un timeout était attendu.")
        } catch let error as AppError {
            #expect(error == .timeout)
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }
}
