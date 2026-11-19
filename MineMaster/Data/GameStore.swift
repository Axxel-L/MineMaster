import Foundation
import Observation
import SwiftData

/// État applicatif central : catalogue, collection, poussière et synchronisation.
///
/// - Authors: Axel L.
@Observable
@MainActor
final class GameStore {
    private let container: ModelContainer
    private let context: ModelContext
    private let engine = LootEngine()

    private(set) var catalog: [CatalogItem] = []
    private(set) var owned: [String: Int] = [:]
    private(set) var dust = 0
    private(set) var totalOpened = 0
    private(set) var lastSync: Date?
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var loadError: AppError?

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    /// Nombre d'items distincts possédés.
    var uniqueCount: Int { owned.count }

    /// Progression de collection entre `0` et `1`.
    var progress: Double {
        catalog.isEmpty ? 0 : Double(uniqueCount) / Double(catalog.count)
    }

    /// Quantité possédée pour un item donné.
    ///
    /// - Parameter item: Item évalué.
    /// - Returns: La quantité possédée, `0` si l'item n'a jamais été obtenu.
    /// - Authors: Axel L.
    func ownedCount(for item: CatalogItem) -> Int {
        owned[item.id] ?? 0
    }

    /// Démarre l'application : catalogue local, puis synchronisation distante.
    ///
    /// - Authors: Axel L.
    func bootstrap() async {
        reloadFromStore()
        if catalog.isEmpty {
            apply(remote: [:])
            reloadFromStore()
        }
        if catalog.isEmpty {
            loadError = .decoding
            return
        }
        await sync()
        prefixImages()
    }

    /// Synchronise les métadonnées distantes sans bloquer l'interface.
    ///
    /// - Authors: Axel L.
    func sync() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let remote = try await CatalogAPI.fetchMetadata()
            apply(remote: remote)
            isOffline = false
            loadError = nil
            let player = currentPlayer()
            player.lastSyncAt = .now
            save()
        } catch let error as AppError {
            isOffline = error == .offline
            loadError = catalog.isEmpty ? error : nil
        } catch {
            isOffline = true
        }
        reloadFromStore()
    }

    /// Ouvre un booster, enregistre les résultats et retourne les tirages.
    ///
    /// - Parameter booster: Booster à ouvrir.
    /// - Returns: Les cinq tirages, avec poussière gagnée et statut de nouveauté.
    /// - Authors: Axel L.
    func open(_ booster: Booster) -> [DrawResult] {
        guard !catalog.isEmpty else { return [] }

        var generator = SystemRandomNumberGenerator()
        let drawn = engine.draw(from: catalog, booster: booster, using: &generator)
        guard !drawn.isEmpty else { return [] }

        let player = currentPlayer()
        var results: [DrawResult] = []

        for item in drawn {
            let isNew = (owned[item.id] ?? 0) == 0
            if let record = collectionRecord(for: item.id) {
                record.quantity += 1
                record.lastObtainedAt = .now
            } else {
                context.insert(CollectionRecord(itemID: item.id))
            }

            let gained = isNew ? 0 : item.rarity.dustValue
            if gained > 0 {
                player.dust += gained
            }
            results.append(DrawResult(item: item, dust: gained, isNew: isNew))
        }

        context.insert(OpeningRecord(booster: booster, itemIDs: drawn.map(\.id)))
        save()
        reloadFromStore()
        return results
    }

    /// Fabrique un item absent de la collection en dépensant de la poussière.
    ///
    /// - Parameter item: Item à fabriquer.
    /// - Returns: `true` si la fabrication a abouti.
    /// - Authors: Axel L.
    @discardableResult
    func craft(_ item: CatalogItem) -> Bool {
        guard ownedCount(for: item) == 0, dust >= item.rarity.craftCost else { return false }

        let player = currentPlayer()
        player.dust -= item.rarity.craftCost
        context.insert(CollectionRecord(itemID: item.id))
        save()
        reloadFromStore()
        return true
    }

    /// Efface la progression locale sans toucher au catalogue.
    ///
    /// - Authors: Axel L.
    func reset() {
        try? context.delete(model: CollectionRecord.self)
        try? context.delete(model: OpeningRecord.self)
        let player = currentPlayer()
        player.dust = 0
        player.lastSyncAt = nil
        save()
        reloadFromStore()
    }

    private func reloadFromStore() {
        let catalogRecords = (try? context.fetch(FetchDescriptor<CatalogItemRecord>())) ?? []
        catalog = catalogRecords
            .compactMap(\.item)
            .sorted { ($0.rarity.rank, $0.displayName) < ($1.rarity.rank, $1.displayName) }

        let collection = (try? context.fetch(FetchDescriptor<CollectionRecord>())) ?? []
        owned = Dictionary(collection.map { ($0.itemID, $0.quantity) }, uniquingKeysWith: +)

        let player = currentPlayer()
        dust = player.dust
        lastSync = player.lastSyncAt
        totalOpened = (try? context.fetchCount(FetchDescriptor<OpeningRecord>())) ?? 0
    }

    private func apply(remote: [String: RemoteItem]) {
        let seeds = SeedCatalog.load()
        guard !seeds.isEmpty else {
            loadError = .invalidResponse
            return
        }

        let existing = (try? context.fetch(FetchDescriptor<CatalogItemRecord>())) ?? []
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let seedIDs = Set(seeds.map(\.id))

        let staleIDs = byID.keys.filter { !seedIDs.contains($0) }
        for id in staleIDs {
            if let record = byID.removeValue(forKey: id) {
                context.delete(record)
            }
        }

        for seed in seeds {
            let record = byID[seed.id] ?? CatalogItemRecord(item: seed)
            if byID[seed.id] == nil {
                context.insert(record)
                byID[seed.id] = record
            }
            record.displayName = remote[seed.id]?.displayName ?? seed.displayName
            record.texturePath = seed.texturePath
            record.rarityRaw = seed.rarity.rawValue
            record.categoryRaw = seed.category.rawValue
            record.stackSize = remote[seed.id]?.stackSize ?? seed.stackSize
        }

        save()
    }

    private func currentPlayer() -> PlayerRecord {
        let descriptor = FetchDescriptor<PlayerRecord>()
        if let player = try? context.fetch(descriptor).first {
            return player
        }
        let player = PlayerRecord()
        context.insert(player)
        return player
    }

    private func collectionRecord(for itemID: String) -> CollectionRecord? {
        var descriptor = FetchDescriptor<CollectionRecord>(
            predicate: #Predicate { $0.itemID == itemID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() {
        try? context.save()
    }

    private func prefixImages() {
        for item in catalog where item.rarity >= .epic {
            guard let url = ImagePolicy.url(for: item.texturePath) else { continue }
            Task { _ = try? await ImagePipeline.shared.data(for: url) }
        }
    }
}
