import Foundation
import ImageIO
import UIKit

/// Politique de construction et de validation des URLs de textures.
enum ImagePolicy {
    nonisolated static let host = "cdn.jsdelivr.net"
    nonisolated static let pathPrefix = "/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/"
    nonisolated static let base = URL(string: "https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/")!

    /// Construit l'URL d'une texture à partir de son chemin relatif.
    ///
    /// - Parameter path: Chemin de la forme `item/diamond.png`.
    /// - Returns: URL absolue validée, ou `nil` si le chemin est hors contrat.
    nonisolated static func url(for path: String) -> URL? {
        guard isTexturePath(path) else { return nil }
        return base.appending(path: path)
    }

    /// Vérifie qu'une URL respecte l'allowlist de téléchargement.
    ///
    /// - Parameter url: URL à contrôler.
    /// - Returns: `true` si le schéma, l'hôte et le préfixe sont autorisés.
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
    nonisolated private static func isSafeName(_ value: Substring) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }
    }
}

/// Image décodée et redimensionnée, transférable hors de l'acteur de chargement.
///
/// `CGImage` n'est pas `Sendable`. L'image portée ici est immuable après
/// construction : aucun code ne modifie ses pixels. Le partage entre l'acteur de
/// décodage et l'interface est donc sûr. La conversion en `UIImage` se fait sur
/// le `MainActor`, où UIKit l'exige.
nonisolated final class DecodedImage: @unchecked Sendable {
    /// Image Core Graphics prête pour l'affichage.
    let cgImage: CGImage
    /// Largeur en pixels.
    let pixelWidth: Int
    /// Hauteur en pixels.
    let pixelHeight: Int

    /// Enveloppe une image décodée.
    ///
    /// - Parameter cgImage: Image immuable.
    init(_ cgImage: CGImage) {
        self.cgImage = cgImage
        pixelWidth = cgImage.width
        pixelHeight = cgImage.height
    }
}

/// Charge, décode et met en cache les textures d'items.
///
/// Les requêtes identiques sont coalescées, le décodage et le redimensionnement
/// s'exécutent hors du `MainActor`, et le nombre de décodages simultanés reste
/// borné par l'acteur. L'interface ne reçoit que des images déjà prêtes.
actor ImagePipeline {
    static let shared: ImagePipeline = {
        #if DEBUG
        if UITestSupport.isEnabled {
            return ImagePipeline(session: UITestSupport.makeImageSession())
        }
        #endif
        return ImagePipeline()
    }()

    private let cache = NSCache<NSString, NSData>()
    private let decodedCache = NSCache<NSString, DecodedImage>()
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var decodeInFlight: [String: Task<DecodedImage, Error>] = [:]
    private let session: URLSession
    private let maxPayload: Int
    private let maximumPixel: CGFloat = 2048

    private init() {
        session = Self.makeSession()
        maxPayload = 2 * 1024 * 1024
        cache.totalCostLimit = 32 * 1024 * 1024
        decodedCache.totalCostLimit = 64 * 1024 * 1024
        decodedCache.countLimit = 256
    }

    /// Crée un pipeline avec une session injectée.
    ///
    /// - Parameters:
    ///   - session: Session réseau utilisée pour les téléchargements.
    ///   - maxPayload: Taille maximale acceptée, en octets.
    init(session: URLSession, maxPayload: Int = 2 * 1024 * 1024) {
        self.session = session
        self.maxPayload = maxPayload
        cache.totalCostLimit = 32 * 1024 * 1024
        decodedCache.totalCostLimit = 64 * 1024 * 1024
        decodedCache.countLimit = 256
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

    /// Télécharge, décode et redimensionne une texture hors du `MainActor`.
    ///
    /// - Parameters:
    ///   - url: URL issue de `ImagePolicy`.
    ///   - maxPixel: Dimension maximale en pixels physiques.
    /// - Returns: L'image décodée, prête pour l'affichage.
    /// - Throws: `AppError.imageUnavailable` si le décodage échoue.
    func decodedImage(for url: URL, maxPixel: CGFloat) async throws -> DecodedImage {
        guard ImagePolicy.isAllowed(url) else { throw AppError.invalidResponse }

        let pixel = min(max(maxPixel.rounded(.up), 32), maximumPixel)
        let keyString = "\(url.absoluteString)|\(Int(pixel))"
        let key = keyString as NSString
        if let cached = decodedCache.object(forKey: key) {
            return cached
        }
        if let running = decodeInFlight[keyString] {
            return try await running.value
        }

        let task = Task<DecodedImage, Error> { [weak self] in
            guard let self else { throw AppError.imageUnavailable }
            let data = try await self.data(for: url)
            try Task.checkCancellation()
            guard let decoded = Self.decode(data, maxPixel: pixel) else {
                throw AppError.imageUnavailable
            }
            return DecodedImage(decoded)
        }

        decodeInFlight[keyString] = task
        defer { decodeInFlight[keyString] = nil }

        let decoded = try await task.value
        let cost = decoded.pixelWidth * decoded.pixelHeight * 4
        decodedCache.setObject(decoded, forKey: key, cost: max(cost, 1))
        return decoded
    }

    /// Décode et redimensionne des octets d'image à la taille d'affichage.
    ///
    /// - Parameters:
    ///   - data: Octets de l'image.
    ///   - maxPixel: Dimension maximale en pixels physiques.
    /// - Returns: L'image décodée, ou `nil` si les octets sont invalides.
    nonisolated private static func decode(_ data: Data, maxPixel: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return thumbnail
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
