import SwiftUI

/// Marché compact : offres à l'achat et items revendables.
struct WatchMarketView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchLink.self) private var link

    @State private var mode: Mode = .buy

    private enum Mode: Hashable {
        case buy
        case sell
    }

    private var offers: [MarketOffer] {
        store.marketOfferings.filter { $0.stock > 0 }
    }

    private var sellable: [CatalogItem] {
        store.catalog.filter { store.ownedCount(for: $0) > 0 }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    WatchDustPill(dust: store.dust)
                    Spacer(minLength: 4)
                    Text("\(mode == .buy ? offers.count : sellable.count) items")
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 4) {
                    modeButton(.buy, title: "Acheter", icon: "cart.fill", tint: Theme.accent)
                    modeButton(.sell, title: "Vendre", icon: "cart.badge.plus", tint: Theme.danger)
                }
                if !link.canPlay {
                    Label("Lecture seule", systemImage: "iphone.slash")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Section(mode == .buy ? "Offres" : "À vendre") {
                if mode == .buy {
                    buyRows
                } else {
                    sellRows
                }
            }
        }
        .navigationTitle("Marché")
    }

    @ViewBuilder
    private var buyRows: some View {
        if offers.isEmpty {
            Text("Aucune offre")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        } else {
            ForEach(offers) { offer in
                NavigationLink {
                    WatchItemDetailView(item: offer.item)
                } label: {
                    row(
                        item: offer.item,
                        detail: "Stock \(offer.stock)",
                        price: offer.buyPrice,
                        tint: Theme.accent
                    )
                }
                .accessibilityIdentifier("watch-market-\(offer.item.id)")
            }
        }
    }

    @ViewBuilder
    private var sellRows: some View {
        if sellable.isEmpty {
            Text("Rien à revendre")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        } else {
            ForEach(sellable) { item in
                NavigationLink {
                    WatchItemDetailView(item: item)
                } label: {
                    row(
                        item: item,
                        detail: "×\(store.ownedCount(for: item))",
                        price: MarketPrice.sell(for: item.rarity),
                        tint: Theme.copper
                    )
                }
                .accessibilityIdentifier("watch-sell-\(item.id)")
            }
        }
    }

    private func row(item: CatalogItem, detail: String, price: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            ItemImageView(item: item, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(item.rarity.displayName) · \(detail)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            Text("\(price)")
                .font(Theme.mono(10, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private func modeButton(_ value: Mode, title: String, icon: String, tint: Color) -> some View {
        let active = mode == value
        return Button {
            mode = value
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(active ? Theme.background : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(active ? tint : Theme.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("watch-market-\(value == .buy ? "buy" : "sell")")
    }
}
