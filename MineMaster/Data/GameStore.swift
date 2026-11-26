import Foundation
import Observation
import SwiftData

/// État applicatif central : catalogue, collection, poussière et synchronisation.
@Observable
@MainActor
final class GameStore {
    typealias DrawProvider = @MainActor (Booster, [CatalogItem], RebirthBoost) -> [CatalogItem]
    typealias BoosterProvider = @MainActor ([CatalogItem]) -> (Booster, BoosterKind)

    private let container: ModelContainer
    private let context: ModelContext
    private let drawProvider: DrawProvider
    private let boosterProvider: BoosterProvider

    private(set) var catalog: [CatalogItem] = []
    private(set) var owned: [String: Int] = [:]
    private(set) var dust = 0
    private(set) var totalOpened = 0
    private(set) var lastSync: Date?
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var loadError: AppError?
    private(set) var isOpening = false
    private(set) var isBootstrapped = false
    private(set) var pullsByItem: [String: Int] = [:]
    private(set) var marketListings: [String: MarketListingRecord] = [:]
    private(set) var marketPurchases = 0
    private(set) var marketSales = 0
    private(set) var rebirthLevel = 0

    /// Appelée après chaque écriture locale, hors restauration distante.
    @ObservationIgnored var onPersist: (() -> Void)?

    @ObservationIgnored private var isApplyingRemote = false
    @ObservationIgnored private var isBootstrapping = false

    init(
        container: ModelContainer,
        drawProvider: @escaping DrawProvider = GameStore.randomDraw,
        boosterProvider: @escaping BoosterProvider = GameStore.randomBooster
    ) {
        self.container = container
        self.context = container.mainContext
        self.drawProvider = drawProvider
        self.boosterProvider = boosterProvider
        reloadFromStore()
    }

    /// Nombre d'items distincts possédés.
    var uniqueCount: Int { owned.count }

    /// Progression de collection entre `0` et `1`.
    var progress: Double {
        catalog.isEmpty ? 0 : Double(uniqueCount) / Double(catalog.count)
    }

    /// Titre d'explorateur courant.
    var explorerTitle: ExplorerTitle {
        .current(for: uniqueCount)
    }

    /// Prochain titre à débloquer.
    var nextExplorerTitle: ExplorerTitle? {
        .next(for: uniqueCount)
    }

    /// Boosts de renaissance courants.
    var rebirthBoost: RebirthBoost { RebirthBoost(level: rebirthLevel) }

    /// Indique si le seuil de renaissance est atteint.
    var canRebirth: Bool { uniqueCount >= Rebirth.minimumUniqueItems }

    /// Quantité possédée pour un item donné.
    ///
    /// - Parameter item: Item évalué.
    /// - Returns: La quantité possédée, `0` si l'item n'a jamais été obtenu.
    func ownedCount(for item: CatalogItem) -> Int {
        owned[item.id] ?? 0
    }

    /// Nombre de tirages locaux de cet item.
    ///
    /// - Parameter item: Item évalué.
    /// - Returns: Le nombre de fois où l'item est apparu dans un booster.
    func pullCount(for item: CatalogItem) -> Int {
        pullsByItem[item.id] ?? 0
    }

    /// Démarre l'application : catalogue local, puis synchronisation distante.
    func bootstrap() async {
        guard !isBootstrapped, !isBootstrapping else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }

        reloadFromStore()
        apply(remote: [:])
        reloadFromStore()
        isBootstrapped = true
        guard !catalog.isEmpty else {
            loadError = .decoding
            return
        }
        ensureMarketSeeded()
        await sync()
        prefixImages()
    }

    /// Synchronise les métadonnées distantes sans bloquer l'interface.
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
    /// Une seule ouverture est acceptée tant que la session courante n'est pas
    /// terminée par `endOpening()`. La poussière des doublons suit le boost de
    /// renaissance courant.
    ///
    /// - Parameters:
    ///   - booster: Booster à ouvrir.
    ///   - kind: Type de contenu filtrant le catalogue.
    /// - Returns: Les cartes tirées, avec poussière gagnée et statut de nouveauté.
    ///   Retourne `[]` si une ouverture est déjà en cours ou si le catalogue est vide.
    func open(_ booster: Booster, kind: BoosterKind = .mixed) -> [DrawResult] {
        guard !isOpening, !catalog.isEmpty else { return [] }

        let pool = kind.filter(catalog)
        let drawn = drawProvider(booster, pool, rebirthBoost)
        guard !drawn.isEmpty else { return [] }
        isOpening = true

        let player = currentPlayer()
        var results: [DrawResult] = []

        for item in drawn {
            let previous = owned[item.id] ?? 0
            let isNew = previous == 0
            if let record = collectionRecord(for: item.id) {
                record.quantity += 1
                record.lastObtainedAt = .now
            } else {
                context.insert(CollectionRecord(itemID: item.id))
            }

            owned[item.id] = previous + 1
            let gained = isNew ? 0 : rebirthBoost.dust(for: item.rarity)
            if gained > 0 {
                player.dust += gained
            }
            results.append(DrawResult(item: item, dust: gained, isNew: isNew))
        }

        context.insert(OpeningRecord(booster: booster, kind: kind, itemIDs: drawn.map(\.id)))
        totalOpened += 1
        for item in drawn {
            pullsByItem[item.id, default: 0] += 1
        }
        dust = player.dust
        save()
        return results
    }

    /// Prépare une ouverture sans consommer le verrou ni enregistrer de tirage.
    ///
    /// Le type et la rareté sont tirés une seule fois, puis affichés sur le pack
    /// scellé. L'ouverture réelle reste déclenchée par le geste de déchirure.
    ///
    /// - Returns: Le plan d'ouverture, ou `nil` si une ouverture est déjà en
    ///   cours ou si le catalogue est vide.
    func planOpening() -> OpeningPlan? {
        guard !isOpening, !catalog.isEmpty else { return nil }
        let pick = boosterProvider(catalog)
        return OpeningPlan(booster: pick.0, kind: pick.1)
    }

    /// Termine la session d'ouverture courante et autorise la suivante.
    func endOpening() {
        isOpening = false
    }

    /// Offres de marché disponibles à l'achat.
    ///
    /// - Returns: Les items en vente, triés par rareté puis par nom.
    /// - Complexity: O(n log n) pour le tri, *n* étant la taille du catalogue.
    var marketOfferings: [MarketOffer] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return marketListings.values
            .compactMap { record in
                guard let item = byID[record.id] else { return nil }
                return MarketOffer(item: item, stock: max(record.stock, 0))
            }
            .sorted { ($0.item.rarity.rank, $0.item.displayName) < ($1.item.rarity.rank, $1.item.displayName) }
    }

    /// Offre de marché d'un item donné.
    ///
    /// - Parameter itemID: Identifiant de l'item.
    /// - Returns: L'offre correspondante, ou `nil` si l'item n'est pas au catalogue.
    func marketOffer(for itemID: String) -> MarketOffer? {
        guard let item = catalog.first(where: { $0.id == itemID }),
              let record = marketListings[itemID] else { return nil }
        return MarketOffer(item: item, stock: max(record.stock, 0))
    }

    /// Achète un item sur le marché.
    ///
    /// Débite la poussière, ajoute l'item à la collection et décrémente le
    /// stock de l'offre.
    ///
    /// - Parameter item: Item à acheter.
    /// - Throws: `AppError.outOfStock` si l'offre est épuisée,
    ///   `AppError.insufficientDust` si la poussière manque.
    func buy(_ item: CatalogItem) throws {
        guard let record = marketListings[item.id] else {
            throw AppError.outOfStock
        }
        guard record.stock > 0 else { throw AppError.outOfStock }

        let price = MarketPrice.buy(for: item.rarity)
        guard dust >= price else { throw AppError.insufficientDust }

        dust -= price
        if let existing = collectionRecord(for: item.id) {
            existing.quantity += 1
            existing.lastObtainedAt = .now
        } else {
            context.insert(CollectionRecord(itemID: item.id))
        }
        owned[item.id, default: 0] += 1

        record.stock -= 1
        marketPurchases += 1
        persistPlayer(dust: dust, purchases: marketPurchases, sales: marketSales, rebirth: rebirthLevel)
        save()
    }

    /// Vend un item de la collection au marché.
    ///
    /// Crédite la poussière, retire un exemplaire de la collection et
    /// réapprovisionne le stock de l'offre.
    ///
    /// - Parameter itemID: Identifiant de l'item à vendre.
    /// - Throws: `AppError.notOwned` si l'item n'est pas possédé.
    func sell(_ itemID: String) throws {
        guard let item = catalog.first(where: { $0.id == itemID }),
              let quantity = owned[itemID], quantity > 0,
              let record = marketListings[itemID] else {
            throw AppError.notOwned
        }

        dust += MarketPrice.sell(for: item.rarity)

        let remaining = quantity - 1
        if remaining > 0 {
            owned[itemID] = remaining
        } else {
            owned.removeValue(forKey: itemID)
        }
        if let existing = collectionRecord(for: itemID) {
            existing.quantity = remaining
            existing.lastObtainedAt = .now
            if remaining <= 0 {
                context.delete(existing)
            }
        }

        record.stock += 1
        marketSales += 1
        persistPlayer(dust: dust, purchases: marketPurchases, sales: marketSales, rebirth: rebirthLevel)
        save()
    }

    /// Effectue une renaissance : remet la collection et la poussière à zéro,
    /// conserve l'historique d'ouverture et incrémente les boosts permanents.
    ///
    /// - Throws: `AppError.rebirthLocked` si le seuil d'items différents n'est
    ///   pas atteint.
    func rebirth() throws {
        guard canRebirth else { throw AppError.rebirthLocked }

        try? context.delete(model: CollectionRecord.self)
        for record in marketListings.values {
            record.stock = 1
        }

        dust = 0
        rebirthLevel += 1
        persistPlayer(dust: 0, purchases: marketPurchases, sales: marketSales, rebirth: rebirthLevel)
        save()
        isOpening = false
        reloadFromStore()
    }

    /// Exporte la progression du compte vers un instantané synchronisable.
    ///
    /// - Parameter updatedAt: Date de référence de l'instantané.
    /// - Returns: Poussière, collection, renaissance et stocks du marché.
    func progressSnapshot(updatedAt: Date = .now) -> ProgressSnapshot {
        ProgressSnapshot(
            dust: dust,
            rebirthLevel: rebirthLevel,
            marketPurchases: marketPurchases,
            marketSales: marketSales,
            owned: owned,
            marketStock: marketListings.mapValues(\.stock),
            updatedAt: updatedAt
        )
    }

    /// Remplace la progression locale par un instantané distant.
    ///
    /// Les identifiants inconnus du catalogue sont ignorés, les quantités sont
    /// bornées et l'historique d'ouverture local n'est jamais modifié.
    ///
    /// - Parameter snapshot: Instantané validé par le synchroniseur.
    /// - Returns: `true` si la progression a été appliquée.
    @discardableResult
    func applyRemote(_ snapshot: ProgressSnapshot) -> Bool {
        guard !catalog.isEmpty else { return false }
        let knownIDs = Set(catalog.map(\.id))

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let existing = (try? context.fetch(FetchDescriptor<CollectionRecord>())) ?? []
        var byID = Dictionary(existing.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })

        for (id, quantity) in snapshot.owned where knownIDs.contains(id) && quantity > 0 {
            let quantity = min(quantity, ProgressSnapshot.maximumQuantity)
            if let record = byID.removeValue(forKey: id) {
                record.quantity = quantity
                record.lastObtainedAt = .now
            } else {
                let record = CollectionRecord(itemID: id)
                record.quantity = quantity
                context.insert(record)
            }
        }
        for stale in byID.values {
            context.delete(stale)
        }

        for (id, stock) in snapshot.marketStock where knownIDs.contains(id) {
            let stock = min(max(stock, 0), ProgressSnapshot.maximumQuantity)
            if let record = marketListings[id] {
                record.stock = stock
            } else {
                context.insert(MarketListingRecord(itemID: id, stock: stock))
            }
        }

        let player = currentPlayer()
        player.dust = snapshot.dust
        player.rebirthLevel = snapshot.rebirthLevel
        player.marketPurchases = snapshot.marketPurchases
        player.marketSales = snapshot.marketSales

        save()
        reloadFromStore()
        return true
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
        marketPurchases = player.marketPurchases
        marketSales = player.marketSales
        rebirthLevel = player.rebirthLevel
        lastSync = player.lastSyncAt

        let openings = (try? context.fetch(FetchDescriptor<OpeningRecord>())) ?? []
        totalOpened = openings.count
        var pulls: [String: Int] = [:]
        for opening in openings {
            for id in opening.itemIDs {
                pulls[id, default: 0] += 1
            }
        }
        pullsByItem = pulls

        let listings = (try? context.fetch(FetchDescriptor<MarketListingRecord>())) ?? []
        marketListings = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
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

    /// Écrit l'état du joueur dans l'enregistrement persistant.
    ///
    /// - Parameters:
    ///   - dust: Poussière courante.
    ///   - purchases: Total des achats marché.
    ///   - sales: Total des ventes marché.
    ///   - rebirth: Nombre de renaissances effectuées.
    private func persistPlayer(dust: Int, purchases: Int, sales: Int, rebirth: Int) {
        let player = currentPlayer()
        player.dust = dust
        player.marketPurchases = purchases
        player.marketSales = sales
        player.rebirthLevel = rebirth
    }

    private func collectionRecord(for itemID: String) -> CollectionRecord? {
        var descriptor = FetchDescriptor<CollectionRecord>(
            predicate: #Predicate { $0.itemID == itemID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Crée les offres de marché manquantes pour les items du catalogue.
    ///
    /// Chaque item absent reçoit une offre avec un stock initial de 1. Les
    /// offres existantes ne sont jamais écrasées.
    private func ensureMarketSeeded() {
        var inserted = false
        for item in catalog where marketListings[item.id] == nil {
            let record = MarketListingRecord(itemID: item.id, stock: 1)
            context.insert(record)
            marketListings[item.id] = record
            inserted = true
        }
        if inserted {
            save()
        }
    }

    private func save() {
        try? context.save()
        guard !isApplyingRemote else { return }
        onPersist?()
    }

    private static func randomBooster(_ catalog: [CatalogItem]) -> (Booster, BoosterKind) {
        let kinds = BoosterKind.allCases.filter { $0.filter(catalog).count >= 5 }
        let kind = kinds.randomElement() ?? .mixed
        let roll = Int.random(in: 0..<100)
        let booster: Booster
        switch roll {
        case ..<60: booster = .common
        case ..<90: booster = .rare
        default: booster = .legendary
        }
        return (booster, kind)
    }

    private static func randomDraw(
        _ booster: Booster,
        _ items: [CatalogItem],
        _ boost: RebirthBoost
    ) -> [CatalogItem] {
        var generator = SystemRandomNumberGenerator()
        return LootEngine().draw(from: items, booster: booster, boost: boost, using: &generator)
    }

    private func prefixImages() {
        for item in catalog where item.rarity >= .epic && MobRenderAPI.url(for: item.id) == nil {
            guard let url = ImagePolicy.url(for: item.texturePath) else { continue }
            Task { _ = try? await ImagePipeline.shared.data(for: url) }
        }
    }
}
