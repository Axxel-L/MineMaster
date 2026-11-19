import Foundation
import UIKit

/// Politique de construction et de validation des URLs de textures.
///
/// - Authors: Axel L.
enum ImagePolicy {
    nonisolated static let host = "cdn.jsdelivr.net"
    nonisolated static let pathPrefix = "/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/"
    nonisolated static let base = URL(string: "https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/")!

    /// Construit l'URL d'une texture à partir de son chemin relatif.
    ///
    /// - Parameter path: Chemin de la forme `item/diamond.png`.
    /// - Returns: URL absolue validée, ou `nil` si le chemin est hors contrat.
    /// - Authors: Axel L.
    nonisolated static func url(for path: String) -> URL? {
        let pattern = #"^(item|block)/[a-z0-9_]+\.png$|^entity/([a-z0-9_]+/)?[a-z0-9_]+\.png$"#
        guard path.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return base.appending(path: path)
    }

    /// Vérifie qu'une URL respecte l'allowlist de téléchargement.
    ///
    /// - Parameter url: URL à contrôler.
    /// - Returns: `true` si le schéma, l'hôte et le préfixe sont autorisés.
    /// - Authors: Axel L.
    nonisolated static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme == "https",
              url.user == nil,
              url.password == nil,
              url.port == nil || url.port == 443,
              url.query == nil,
              url.fragment == nil else {
            return false
        }

        if url.host == "minecraft.wiki" {
            let path = url.path
            guard path.hasPrefix("/images/"),
                  !path.split(separator: "/").contains(".."),
                  ["png", "gif", "webp"].contains(where: { path.lowercased().hasSuffix(".\($0)") }) else {
                return false
            }
            return true
        }

        guard url.host == host, url.path.hasPrefix(pathPrefix) else { return false }
        let relative = String(url.path.dropFirst(pathPrefix.count))
        let pattern = #"^(item|block)/[a-z0-9_]+\.png$|^entity/([a-z0-9_]+/)?[a-z0-9_]+\.png$"#
        return relative.range(of: pattern, options: .regularExpression) != nil
    }
}

/// Charge et met en cache les textures d'items.
///
/// Les requêtes identiques sont coalescées, les réponses sont validées avant mise en cache
/// et le nombre de connexions simultanées est borné par `URLSession`.
///
/// - Authors: Axel L.
actor ImagePipeline {
    static let shared = ImagePipeline()

    private let cache = NSCache<NSString, NSData>()
    private var inFlight: [String: Task<Data, Error>] = [:]
    private let session: URLSession
    private let maxPayload: Int

    private init() {
        session = Self.makeSession()
        maxPayload = 2 * 1024 * 1024
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Crée un pipeline avec une session injectée.
    ///
    /// - Parameters:
    ///   - session: Session réseau utilisée pour les téléchargements.
    ///   - maxPayload: Taille maximale acceptée, en octets.
    /// - Authors: Axel L.
    init(session: URLSession, maxPayload: Int = 2 * 1024 * 1024) {
        self.session = session
        self.maxPayload = maxPayload
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "ImageCache") {
            configuration.urlCache = URLCache(
                memoryCapacity: 8 * 1024 * 1024,
                diskCapacity: 200 * 1024 * 1024,
                directory: directory
            )
        }
        return URLSession(configuration: configuration)
    }

    /// Télécharge la texture d'une URL autorisée.
    ///
    /// - Parameter url: URL issue de `ImagePolicy`.
    /// - Returns: Les octets PNG validés.
    /// - Throws: `AppError` si l'URL, la réponse ou la charge utile sont invalides.
    /// - Authors: Axel L.
    func data(for url: URL) async throws -> Data {
        guard ImagePolicy.isAllowed(url) else { throw AppError.invalidResponse }

        let key = url.absoluteString as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        if let running = inFlight[url.absoluteString] {
            return try await running.value
        }

        let task = Task<Data, Error> { [session, maxPayload] in
            var request = URLRequest(url: url)
            request.setValue("image/png", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()

            guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
            guard (200...299).contains(http.statusCode) else {
                throw http.statusCode == 429 ? AppError.rateLimited : AppError.imageUnavailable
            }
            guard let mime = http.mimeType, mime.hasPrefix("image/") else { throw AppError.invalidResponse }
            guard data.count <= maxPayload else { throw AppError.invalidResponse }

            return data
        }

        inFlight[url.absoluteString] = task
        defer { inFlight[url.absoluteString] = nil }

        do {
            let data = try await task.value
            cache.setObject(data as NSData, forKey: key, cost: data.count)
            return data
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed:
                throw AppError.offline
            case .timedOut:
                throw AppError.timeout
            default:
                throw AppError.invalidResponse
            }
        }
    }
}
