import Foundation
import Testing
import UIKit
@testable import MineMaster

@MainActor
@Suite(
    "Intégration CDN (réseau réel)",
    .enabled(if: ProcessInfo.processInfo.environment["MINEMASTER_NETWORK_TESTS"] == "1")
)
struct CDNIntegrationTests {
    @Test("Toutes les textures du catalogue embarqué sont récupérables et décodables")
    func toutesLesTextures() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let pipeline = ImagePipeline(session: URLSession(configuration: configuration))
        var failures: [String] = []

        for item in SeedCatalog.load() {
            guard let url = ImagePolicy.url(for: item.texturePath) else {
                failures.append(item.id)
                continue
            }
            do {
                let data = try await pipeline.data(for: url)
                if UIImage(data: data) == nil { failures.append(item.id) }
            } catch {
                failures.append(item.id)
            }
        }

        #expect(failures.isEmpty, "Textures indisponibles : \(failures.joined(separator: ", "))")
    }
}
