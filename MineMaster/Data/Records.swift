import Foundation
import SwiftData

/// Item du catalogue persisté localement.
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
@Model
final class PlayerRecord {
    @Attribute(.unique) var key: String
    var dust: Int
    var marketPurchases: Int = 0
    var marketSales: Int = 0
    var rebirthLevel: Int = 0
    var lastSyncAt: Date?

    init(key: String = "player") {
        self.key = key
        dust = 0
        marketPurchases = 0
        marketSales = 0
        rebirthLevel = 0
        lastSyncAt = nil
    }
}

/// Historique d'une ouverture de booster.
@Model
final class OpeningRecord {
    var id: UUID
    var boosterRaw: String
    var kindRaw: String = BoosterKind.mixed.rawValue
    var openedAt: Date
    var itemIDs: [String]

    init(booster: Booster, kind: BoosterKind = .mixed, itemIDs: [String]) {
        id = UUID()
        boosterRaw = booster.rawValue
        kindRaw = kind.rawValue
        openedAt = .now
        self.itemIDs = itemIDs
    }
}

/// Offre du marché pour un item du catalogue.
///
/// L'application agit comme contrepartie unique : achat et revente passent par
/// ces offres, sans base de données distante. Seul le stock est persisté ; les
/// prix sont recalculés depuis la rareté, donc jamais falsifiables côté stockage.
@Model
final class MarketListingRecord {
    @Attribute(.unique) var id: String
    var stock: Int

    init(itemID: String, stock: Int) {
        id = itemID
        self.stock = stock
    }
}
