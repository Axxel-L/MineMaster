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
        guard isTexturePath(path) else { return nil }
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
        return isTexturePath(relative)
    }

    /// Vérifie un chemin de texture sans compiler d'expression régulière.
    ///
    /// - Parameter path: Chemin relatif à valider.
    /// - Returns: `true` pour `item/<nom>.png`, `block/<nom>.png` ou
    ///   `entity/[<dossier>/]<nom>.png`.
    /// - Authors: Axel L.
    nonisolated private static func isTexturePath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 || (parts.count == 3 && parts[0] == "entity") else { return false }
        guard parts[0] == "item" || parts[0] == "block" || parts[0] == "entity" else { return false }

        let file = parts[parts.count - 1]
        guard file.hasSuffix(".png"), isSafeName(file.dropLast(4)) else { return false }
        return parts.count == 2 || isSafeName(parts[1])
    }

    /// Vérifie qu'un segment ne contient que minuscules, chiffres et underscore.
    ///
    /// - Parameter value: Segment à contrôler.
    /// - Returns: `true` si le segment est non vide et sûr.
    /// - Authors: Axel L.
    nonisolated private static func isSafeName(_ value: Substring) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }
    }
}

/// Cache mémoire des images déjà décodées.
///
/// Le cache est borné et laissé à la gestion de `NSCache` sous pression mémoire.
///
/// - Authors: Axel L.
@MainActor
final class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
        cache.countLimit = 256
    }

    /// Retourne une image en cache.
    ///
    /// - Parameter url: URL de l'image.
    /// - Returns: L'image décodée, ou `nil` si absente du cache.
    /// - Authors: Axel L.
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    /// Ajoute une image décodée au cache.
    ///
    /// - Parameters:
    ///   - image: Image décodée.
    ///   - url: URL source de l'image.
    /// - Authors: Axel L.
    func insert(_ image: UIImage, for url: URL) {
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: max(Int(pixels * 4), 1))
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
        cache.totalCostLimit = 32 * 1024 * 1024
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
        cache.totalCostLimit = 32 * 1024 * 1024
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
