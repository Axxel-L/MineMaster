import Foundation
import Testing
@testable import MineMaster

@Suite("Pipeline d'images", .serialized)
struct ImagePipelineTests {
    private let url = ImagePolicy.url(for: "item/diamond.png")!

    @Test("Une URL hors allowlist est refusée sans requête")
    func rejectsForeignURL() async {
        let pipeline = makePipeline()
        let foreign = URL(string: "https://evil.example/item/diamond.png")!

        await expectAppError(.invalidResponse) {
            _ = try await pipeline.data(for: foreign)
        }
        #expect(StubURLProtocol.requestCount == 0)
    }

    @Test("Un type MIME non image est refusé")
    func rejectsNonImageMIME() async {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url, mime: "text/plain"), Data([1, 2, 3]))
        }
        let pipeline = makePipeline()

        await expectAppError(.invalidResponse) {
            _ = try await pipeline.data(for: url)
        }
    }

    @Test("Un statut hors 200...299 est refusé")
    func rejectsInvalidStatus() async {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url, status: 404), Data([1, 2, 3]))
        }
        let pipeline = makePipeline()

        await expectAppError(.imageUnavailable) {
            _ = try await pipeline.data(for: url)
        }
    }

    @Test("Un statut 429 est signalé comme limitation")
    func reportsRateLimit() async {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url, status: 429), Data([1, 2, 3]))
        }
        let pipeline = makePipeline()

        await expectAppError(.rateLimited) {
            _ = try await pipeline.data(for: url)
        }
    }

    @Test("Une charge utile trop grande est refusée")
    func rejectsOversizedPayload() async {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url), Data([1, 2, 3, 4]))
        }
        let pipeline = makePipeline(maxPayload: 3)

        await expectAppError(.invalidResponse) {
            _ = try await pipeline.data(for: url)
        }
    }

    @Test("Le cache sert le second appel sans requête réseau")
    func cacheServesSecondCall() async throws {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url), Data([1, 2, 3]))
        }
        let pipeline = makePipeline()

        let first = try await pipeline.data(for: url)
        let second = try await pipeline.data(for: url)

        #expect(first == second)
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test("Des appels simultanés produisent un seul appel réseau")
    func coalescesConcurrentCalls() async throws {
        let gate = RequestGate()
        StubURLProtocol.configure { [url] _ in
            gate.signalStarted()
            gate.waitForRelease()
            return (makeResponse(for: url), Data([1, 2, 3]))
        }
        let pipeline = makePipeline()

        let first = Task { try await pipeline.data(for: url) }
        var iterator = gate.started.makeAsyncIterator()
        _ = await iterator.next()

        let second = Task { try await pipeline.data(for: url) }
        await Task.yield()
        gate.open()

        let firstData = try await first.value
        let secondData = try await second.value

        #expect(firstData == secondData)
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test("Une image valide est décodée hors du MainActor à la taille demandée")
    func decodesImageAtRequestedSize() async throws {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url), Self.onePixelPNG)
        }
        let pipeline = makePipeline()

        let decoded = try await pipeline.decodedImage(for: url, maxPixel: 32)

        #expect((1...32).contains(decoded.pixelWidth))
        #expect((1...32).contains(decoded.pixelHeight))
    }

    @Test("Des octets non décodables échouent sans bloquer le pipeline")
    func rejectsUndecodableImage() async {
        StubURLProtocol.configure { [url] _ in
            (makeResponse(for: url), Data([0, 1, 2, 3]))
        }
        let pipeline = makePipeline()

        await expectAppError(.imageUnavailable) {
            _ = try await pipeline.decodedImage(for: url, maxPixel: 64)
        }
    }

    private static let onePixelPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    private func makePipeline(maxPayload: Int = 2 * 1024 * 1024) -> ImagePipeline {
        ImagePipeline(session: makeStubSession(), maxPayload: maxPayload)
    }
}
