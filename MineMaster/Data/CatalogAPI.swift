import Foundation

/// Métadonnées distantes d'un item Minecraft.
///
/// - Authors: Axel L.
struct RemoteItem: Decodable, Sendable {
    let name: String
    let displayName: String?
    let stackSize: Int?
}

/// Client du catalogue distant.
///
/// - Authors: Axel L.
enum CatalogAPI {
    static let metadataURL = URL(string: "https://raw.githubusercontent.com/PrismarineJS/minecraft-data/master/data/pc/1.21.4/items.json")!
    static let metadataHost = "raw.githubusercontent.com"
    static let maxPayload = 5 * 1024 * 1024
    static let maxItems = 5_000

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }()

    /// Récupère les métadonnées du catalogue indexées par identifiant.
    ///
    /// - Returns: Dictionnaire `identifiant → métadonnées`.
    /// - Throws: `AppError` si le réseau, le statut, la taille ou le décodage échouent.
    /// - Authors: Axel L.
    static func fetchMetadata() async throws -> [String: RemoteItem] {
        guard metadataURL.scheme == "https", metadataURL.host == metadataHost else {
            throw AppError.invalidResponse
        }

        var request = URLRequest(url: metadataURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw AppError.invalidResponse
            }
            guard data.count <= maxPayload else { throw AppError.invalidResponse }

            let items = try JSONDecoder().decode([RemoteItem].self, from: data)
            guard items.count <= maxItems else { throw AppError.invalidResponse }

            return Dictionary(items.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
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
        } catch is DecodingError {
            throw AppError.decoding
        }
    }
}

/// Catalogue de secours embarqué.
///
/// - Authors: Axel L.
enum SeedCatalog {
    private struct File: Decodable {
        let version: String
        let items: [Entry]
    }

    private struct Entry: Decodable {
        let id: String
        let texture: String
        let rarity: String
        let category: String
    }

    /// Charge le catalogue embarqué et le convertit en items de domaine.
    ///
    /// - Returns: La liste des items, vide si la ressource est absente ou invalide.
    /// - Authors: Axel L.
    static func load() -> [CatalogItem] {
        guard let url = Bundle.main.url(forResource: "ItemCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }

        return file.items.compactMap { entry in
            guard let rarity = Rarity(rawValue: entry.rarity),
                  let category = ItemCategory(rawValue: entry.category),
                  ImagePolicy.url(for: entry.texture) != nil else {
                return nil
            }
            return CatalogItem(
                id: entry.id,
                displayName: pretty(entry.id),
                texturePath: entry.texture,
                rarity: rarity,
                category: category,
                stackSize: 64
            )
        }
    }

    /// Convertit un identifiant technique en libellé lisible.
    ///
    /// - Parameter id: Identifiant de la forme `oak_log`.
    /// - Returns: Libellé de la forme `Oak Log`.
    /// - Authors: Axel L.
    static func pretty(_ id: String) -> String {
        id.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
