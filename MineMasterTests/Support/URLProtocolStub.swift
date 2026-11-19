import Foundation
import os
@testable import MineMaster

/// Intercepte les requêtes réseau des tests sans accès Internet.
///
/// - Authors: Axel L.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    struct State: Sendable {
        var handler: Handler?
        var requestCount = 0
    }

    static let state = OSAllocatedUnfairLock(initialState: State())

    static func configure(_ handler: @escaping Handler) {
        state.withLock {
            $0.handler = handler
            $0.requestCount = 0
        }
    }

    static func reset() {
        state.withLock {
            $0 = State()
        }
    }

    static var requestCount: Int {
        state.withLock { $0.requestCount }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler = Self.state.withLock { state -> Handler? in
            state.requestCount += 1
            return state.handler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: AppError.invalidResponse)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Session `URLSession` branchée sur `StubURLProtocol`.
///
/// - Returns: Une session éphémère sans cache.
/// - Authors: Axel L.
func makeStubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration)
}

/// Construit une réponse HTTP de test.
///
/// - Parameters:
///   - url: URL de la requête.
///   - status: Code de statut.
///   - mime: Type MIME annoncé.
/// - Returns: La réponse HTTP.
/// - Authors: Axel L.
func makeResponse(
    for url: URL,
    status: Int = 200,
    mime: String = "image/png"
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": mime]
    )!
}

/// Porte de synchronisation entre un test et une requête bloquée.
///
/// - Authors: Axel L.
struct RequestGate: Sendable {
    let started: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let release = DispatchSemaphore(value: 0)

    init() {
        let pair = AsyncStream<Void>.makeStream()
        started = pair.stream
        continuation = pair.continuation
    }

    func signalStarted() {
        continuation.yield(())
    }

    func waitForRelease() {
        release.wait()
    }

    func open() {
        release.signal()
    }
}
