import SwiftUI

/// Collection compacte, filtrable par possession et rareté.
struct WatchCollectionView: View {
    @Environment(GameStore.self) private var store

    @State private var ownedOnly = false
    @State private var rarity: Rarity?

    private var filtered: [CatalogItem] {
        store.catalog.filter { item in
            let matchesOwned = !ownedOnly || store.ownedCount(for: item) > 0
            let matchesRarity = rarity == nil || item.rarity == rarity
            return matchesOwned && matchesRarity
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Découverts", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(store.uniqueCount)/\(store.catalog.count)")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                Toggle("Possédés", isOn: $ownedOnly)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .accessibilityIdentifier("watch-owned-filter")
                Picker("Rareté", selection: $rarity) {
                    Text("Toutes").tag(Optional<Rarity>.none)
                    ForEach(Rarity.allCases) { value in
                        Text(value.displayName).tag(Optional(value))
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
            }

            Section("Items") {
                if filtered.isEmpty {
                    Text("Aucun item")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(filtered) { item in
                        NavigationLink {
                            WatchItemDetailView(item: item)
                        } label: {
                            row(item)
                        }
                        .accessibilityIdentifier("watch-item-\(item.id)")
                    }
                }
            }
        }
        .navigationTitle("Collection")
    }

    private func row(_ item: CatalogItem) -> some View {
        let count = store.ownedCount(for: item)
        return HStack(spacing: 8) {
            ItemImageView(item: item, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(item.rarity.displayName) · \(item.category.displayName)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            Text(count > 0 ? "×\(count)" : "—")
                .font(Theme.mono(9, weight: .bold))
                .foregroundStyle(count > 0 ? item.rarity.color : Theme.textSecondary.opacity(0.6))
        }
        .opacity(count > 0 ? 1 : 0.55)
    }
}

/// Fiche détail compacte d'un item.
struct WatchItemDetailView: View {
    let item: CatalogItem

    @Environment(GameStore.self) private var store
    @Environment(WatchLink.self) private var link

    @State private var stats: WatchItemStats?
    @State private var errorMessage: String?
    @State private var isWorking = false

    private var count: Int { store.ownedCount(for: item) }
    private var offer: MarketOffer? { store.marketOffer(for: item.id) }
    private var affordable: Bool { store.dust >= MarketPrice.buy(for: item.rarity) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ItemImageView(item: item, size: 64)
                Text(item.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                RarityBadge(rarity: item.rarity)

                VStack(spacing: 5) {
                    WatchInfoRow(title: "Catégorie", value: item.category.displayName)
                    WatchInfoRow(title: "Possédés", value: "\(count)")
                    WatchInfoRow(title: "Achat", value: "\(MarketPrice.buy(for: item.rarity))", tint: Theme.accent)
                    WatchInfoRow(title: "Vente", value: "\(MarketPrice.sell(for: item.rarity))", tint: Theme.copper)
                    WatchInfoRow(title: "Stock", value: "\(offer?.stock ?? 0)")
                }
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))

                VStack(spacing: 5) {
                    WatchInfoRow(title: "Tes tirages", value: "\(stats?.localPulls ?? store.pullCount(for: item))")
                    WatchInfoRow(
                        title: "Tirages monde",
                        value: stats.map { "\($0.globalPulls)" } ?? "—",
                        tint: Theme.accent
                    )
                    WatchInfoRow(
                        title: "Échanges monde",
                        value: stats.map { "\($0.globalTrades)" } ?? "—",
                        tint: Theme.copper
                    )
                }
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .accessibilityIdentifier("watch-community-stats")

                if (offer?.stock ?? 0) > 0 {
                    Button {
                        Task { await buy() }
                    } label: {
                        Label("Acheter · \(MarketPrice.buy(for: item.rarity))", systemImage: "cart.fill")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(affordable ? Theme.accent : Theme.textSecondary)
                    .disabled(!affordable || !link.canPlay || isWorking)
                    .accessibilityIdentifier("watch-buy")
                }

                if count > 0 {
                    Button {
                        Task { await sell() }
                    } label: {
                        Label("Vendre · +\(MarketPrice.sell(for: item.rarity))", systemImage: "cart.badge.plus")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.danger)
                    .disabled(!link.canPlay || isWorking)
                    .accessibilityIdentifier("watch-sell")
                }

                if !link.canPlay {
                    Text("Lecture seule : ouvre l'iPhone pour échanger.")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Détail")
        .task {
            await refreshStats()
        }
    }

    private func buy() async {
        isWorking = true
        defer { isWorking = false }
        errorMessage = await link.buy(item)
        if errorMessage == nil {
            await refreshStats()
        }
    }

    private func sell() async {
        isWorking = true
        defer { isWorking = false }
        errorMessage = await link.sell(item.id)
        if errorMessage == nil {
            await refreshStats()
        }
    }

    private func refreshStats() async {
        guard link.canPlay else { return }
        if let updated = await link.itemStats(item.id) {
            stats = updated
        }
    }
}
