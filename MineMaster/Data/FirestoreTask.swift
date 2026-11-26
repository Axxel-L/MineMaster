import Foundation
import Synchronization

/// Exécute une opération Firestore en la bornant dans le temps.
///
/// Les méthodes asynchrones importées du SDK ne répondent pas à l'annulation :
/// un groupe de tâches attendrait indéfiniment une opération bloquée. Ici la
/// continuation est reprise une seule fois, par l'opération ou par le délai, et
/// l'éventuelle réponse tardive est ignorée.
enum FirestoreTask {
    /// Délai maximal accordé à une opération Firestore.
    nonisolated static let defaultTimeout = 12.0

    /// Exécute une opération Firestore avec un délai maximal.
    ///
    /// - Parameters:
    ///   - seconds: Délai maximal avant `AppError.timeout`.
    ///   - operation: Opération à exécuter.
    /// - Returns: La valeur retournée par l'opération.
    /// - Throws: L'erreur de l'opération, ou `AppError.timeout`.
    nonisolated static func bounded<T: Sendable>(
        seconds: Double = defaultTimeout,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let answered = Mutex(false)
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    resume(answered, continuation, with: .success(try await operation()))
                } catch {
                    resume(answered, continuation, with: .failure(error))
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                resume(answered, continuation, with: .failure(AppError.timeout))
            }
        }
    }

    private nonisolated static func resume<T: Sendable>(
        _ answered: borrowing Mutex<Bool>,
        _ continuation: CheckedContinuation<T, Error>,
        with result: Result<T, Error>
    ) {
        let isFirstAnswer = answered.withLock { answered in
            guard !answered else { return false }
            answered = true
            return true
        }
        guard isFirstAnswer else { return }
        continuation.resume(with: result)
    }
}
