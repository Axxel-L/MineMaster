import Foundation
import SwiftData

#if DEBUG

/// Environnement déterministe réservé aux tests d'interface.
///
/// Activé uniquement par l'argument de lancement `-uiTesting`, il remplace le
/// catalogue embarqué par six items fixes, coupe la synchronisation réseau et
/// utilise un conteneur SwiftData en mémoire.
enum UITestSupport {
    /// Argument de lancement activant l'environnement de test.
    nonisolated static let launchArgument = "-uiTesting"

    /// Indique si l'application tourne pour un test d'interface.
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Argument préparant une collection éligible à la renaissance.
    nonisolated static let rebirthReadyArgument = "-uiTestingRebirthReady"

    /// Indique si la collection de test doit être prête à renaître.
    nonisolated static var isRebirthReady: Bool {
        ProcessInfo.processInfo.arguments.contains(rebirthReadyArgument)
    }

    /// Construit une session réseau qui refuse toute requête d'image.
    ///
    /// - Returns: Une session dont chaque requête échoue immédiatement hors ligne.
    nonisolated static func makeImageSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineImageProtocol.self]
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 1
        return URLSession(configuration: configuration)
    }

    /// Construit le magasin de test, ou `nil` si le conteneur est indisponible.
    ///
    /// - Returns: Un magasin en mémoire, sans réseau, avec un tirage fixe.
    static func makeStore() -> GameStore? {
        let schema = GameContainer.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            return nil
        }

        for item in fixtures {
            container.mainContext.insert(CatalogItemRecord(item: item))
        }
        if isRebirthReady {
            for index in 0..<Rebirth.minimumUniqueItems {
                container.mainContext.insert(CollectionRecord(itemID: "seed-\(index)"))
            }
        }

        do {
            try container.mainContext.save()
        } catch {
            return nil
        }

        return GameStore(
            container: container,
            drawProvider: draw,
            boosterProvider: { _ in (.rare, .mixed) },
            syncOnBootstrap: false
        )
    }

    private static let drawnIDs = ["diamond", "dirt", "iron_ingot", "nether_star", "stick"]

    private static func draw(
        _ booster: Booster,
        _ pool: [CatalogItem],
        _ boost: RebirthBoost
    ) -> [CatalogItem] {
        drawnIDs.compactMap { id in pool.first { $0.id == id } }
    }

    private static let fixtures = [
        CatalogItem(
            id: "dirt",
            displayName: "Dirt",
            texturePath: "block/dirt.png",
            rarity: .common,
            category: .block,
            stackSize: 64
        ),
        CatalogItem(
            id: "stick",
            displayName: "Stick",
            texturePath: "item/stick.png",
            rarity: .common,
            category: .material,
            stackSize: 64
        ),
        CatalogItem(
            id: "iron_ingot",
            displayName: "Iron Ingot",
            texturePath: "item/iron_ingot.png",
            rarity: .uncommon,
            category: .material,
            stackSize: 64
        ),
        CatalogItem(
            id: "diamond",
            displayName: "Diamond",
            texturePath: "item/diamond.png",
            rarity: .rare,
            category: .material,
            stackSize: 64
        ),
        CatalogItem(
            id: "nether_star",
            displayName: "Nether Star",
            texturePath: "item/nether_star.png",
            rarity: .legendary,
            category: .special,
            stackSize: 64
        ),
        CatalogItem(
            id: "apple",
            displayName: "Apple",
            texturePath: "item/apple.png",
            rarity: .common,
            category: .food,
            stackSize: 64
        )
    ]
}

/// Protocol réseau qui refuse toute requête, réservé aux tests d'interface.
private nonisolated final class OfflineImageProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
#endif
