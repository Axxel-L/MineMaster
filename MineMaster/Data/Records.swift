import Foundation
import SwiftData

/// Item du catalogue persisté localement.
///
/// - Authors: Axel L.
@Model
final class CatalogItemRecord {
    @Attribute(.unique) var id: String
    var displayName: String
    var texturePath: String
    var rarityRaw: String
    var categoryRaw: String
    var stackSize: Int

    init(item: CatalogItem) {
        id = item.id
        displayName = item.displayName
        texturePath = item.texturePath
        rarityRaw = item.rarity.rawValue
        categoryRaw = item.category.rawValue
        stackSize = item.stackSize
    }

    /// Convertit l'enregistrement en item de domaine.
    ///
    /// - Returns: L'item correspondant, ou `nil` si les valeurs persistées sont invalides.
    /// - Authors: Axel L.
    var item: CatalogItem? {
        guard let rarity = Rarity(rawValue: rarityRaw),
              let category = ItemCategory(rawValue: categoryRaw) else {
            return nil
        }
        return CatalogItem(
            id: id,
            displayName: displayName,
            texturePath: texturePath,
            rarity: rarity,
            category: category,
            stackSize: stackSize
        )
    }
}

/// Quantité possédée d'un item.
///
/// - Authors: Axel L.
@Model
final class CollectionRecord {
    @Attribute(.unique) var itemID: String
    var quantity: Int
    var firstObtainedAt: Date
    var lastObtainedAt: Date

    init(itemID: String) {
        self.itemID = itemID
        quantity = 1
        firstObtainedAt = .now
        lastObtainedAt = .now
    }
}

/// État local du joueur.
///
/// - Authors: Axel L.
@Model
final class PlayerRecord {
    @Attribute(.unique) var key: String
    var dust: Int
    var lastSyncAt: Date?

    init(key: String = "player") {
        self.key = key
        dust = 0
        lastSyncAt = nil
    }
}

/// Historique d'une ouverture de booster.
///
/// - Authors: Axel L.
@Model
final class OpeningRecord {
    var id: UUID
    var boosterRaw: String
    var openedAt: Date
    var itemIDs: [String]

    init(booster: Booster, itemIDs: [String]) {
        id = UUID()
        boosterRaw = booster.rawValue
        openedAt = .now
        self.itemIDs = itemIDs
    }
}
