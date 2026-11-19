import Foundation
import SwiftData
@testable import MineMaster

/// Fabrique des items de test valides pour le catalogue.
///
/// - Authors: Axel L.
enum Fixtures {
    static func item(
        _ id: String,
        rarity: Rarity = .common,
        category: ItemCategory = .material
    ) -> CatalogItem {
        let folder = category == .block ? "block" : "item"
        return CatalogItem(
            id: id,
            displayName: id,
            texturePath: "\(folder)/\(id).png",
            rarity: rarity,
            category: category,
            stackSize: 64
        )
    }

    static func items(_ count: Int, rarity: Rarity = .common) -> [CatalogItem] {
        (1...count).map { item("test_\($0)", rarity: rarity) }
    }

    static func mixedItems() -> [CatalogItem] {
        var result: [CatalogItem] = []
        for rarity in Rarity.allCases {
            result.append(contentsOf: (1...4).map {
                item("mixed_\(rarity.rawValue)_\($0)", rarity: rarity)
            })
        }
        return result
    }
}

/// Conteneur SwiftData en mémoire et magasin applicatif associé.
///
/// - Authors: Axel L.
@MainActor
struct StoreFixture {
    let store: GameStore
    let container: ModelContainer
}

/// Construit un `GameStore` isolé avec un conteneur en mémoire.
///
/// - Parameters:
///   - items: Items insérés dans le catalogue.
///   - dust: Poussière initiale du joueur.
///   - draw: Tirage injecté, déterministe dans les tests.
/// - Returns: Le magasin et son conteneur.
/// - Throws: Une erreur SwiftData si le conteneur ne peut pas être créé.
/// - Authors: Axel L.
@MainActor
func makeStore(
    items: [CatalogItem] = [],
    dust: Int = 0,
    draw: @escaping GameStore.DrawProvider = { _, _ in [] }
) throws -> StoreFixture {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: CatalogItemRecord.self,
        CollectionRecord.self,
        PlayerRecord.self,
        OpeningRecord.self,
        configurations: configuration
    )
    let context = container.mainContext

    for item in items {
        context.insert(CatalogItemRecord(item: item))
    }
    if dust > 0 {
        let player = PlayerRecord()
        player.dust = dust
        context.insert(player)
    }
    try context.save()

    return StoreFixture(
        store: GameStore(container: container, drawProvider: draw),
        container: container
    )
}
