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
        let answer = FirestoreAnswer<T>()
        return try await withCheckedThrowingContinuation { continuation in
            answer.install(continuation)
            Task {
                do {
                    answer.resume(with: .success(try await operation()))
                } catch {
                    answer.resume(with: .failure(error))
                }
            }
            Task {
                do {
                    try await Task.sleep(for: .seconds(seconds))
                } catch {
                    return
                }
                answer.resume(with: .failure(AppError.timeout))
            }
        }
    }
}

/// Réponse unique protégée par un verrou, partageable entre les deux tâches.
private nonisolated final class FirestoreAnswer<T: Sendable>: Sendable {
    private struct State {
        var answered = false
        var continuation: CheckedContinuation<T, Error>?
    }

    private let state = Mutex<State>(State())

    func install(_ continuation: CheckedContinuation<T, Error>) {
        state.withLock { state in
            state.continuation = continuation
        }
    }

    func resume(with result: Result<T, Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<T, Error>? in
            guard !state.answered, let continuation = state.continuation else { return nil }
            state.answered = true
            state.continuation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }
}
