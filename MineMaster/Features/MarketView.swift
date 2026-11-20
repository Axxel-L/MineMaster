import SwiftUI

/// Marché : achat et revente d'items contre de la poussière.
///
/// L'application fait contrepartie unique. Aucun réseau, aucune simulation :
/// la poussière est réellement débitée ou créditée et la collection est mise
/// à jour à chaque transaction.
struct MarketView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var mode: MarketMode = .buy
    @State private var errorMessage: String?

    private var columns: [GridItem] {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 220 : 150
        return [GridItem(.adaptive(minimum: minimum, maximum: 300), spacing: 12)]
    }

    private var buyOffers: [MarketOffer] {
        store.marketOfferings.filter { $0.stock > 0 }
    }

    private var sellable: [CatalogItem] {
        store.catalog.filter { store.ownedCount(for: $0) > 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceM) {
                        balance
                        modePicker
                        grid
                        if let errorMessage {
                            errorBanner(errorMessage)
                        }
                    }
                    .padding(.horizontal, Theme.spaceM)
                    .padding(.top, Theme.spaceM)
                    .padding(.bottom, 110)
                    .animation(.snappy, value: mode)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Marché")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var balance: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { balanceCards }
            } else {
                HStack(spacing: 12) { balanceCards }
            }
        }
    }

    @ViewBuilder
    private var balanceCards: some View {
        StatCard(
            title: "Poussière",
            value: "\(store.dust)",
            systemImage: "circle.hexagongrid.fill",
            tint: Rarity.epic.color
        )
        StatCard(
            title: mode == .buy ? "En vente" : "À vendre",
            value: "\(mode == .buy ? buyOffers.count : sellable.count)",
            systemImage: mode == .buy ? "cart.fill" : "square.stack.3d.up.fill",
            tint: mode == .buy ? Theme.accent : Theme.danger
        )
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeButton(.buy, title: "Acheter", icon: "cart.fill", tint: Theme.accent)
            modeButton(.sell, title: "Vendre", icon: "cart.badge.plus", tint: Theme.danger)
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5))
    }

    private func modeButton(_ value: MarketMode, title: String, icon: String, tint: Color) -> some View {
        let active = mode == value
        return Button {
            withAnimation(.snappy) {
                errorMessage = nil
                mode = value
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(active ? Theme.background : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(active ? tint : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    @ViewBuilder
    private var grid: some View {
        let isEmpty = mode == .buy ? buyOffers.isEmpty : sellable.isEmpty

        if isEmpty {
            EmptyStateView(
                icon: mode == .buy ? "cart.fill" : "square.stack.3d.up.fill",
                title: mode == .buy ? "Rien à vendre" : "Rien à revendre",
                message: mode == .buy
                    ? "Le marché est vide pour l'instant."
                    : "Ouvre des packs pour récupérer des items."
            )
            .padding(.top, Theme.spaceL)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                if mode == .buy {
                    ForEach(buyOffers) { offer in
                        buyCard(offer)
                    }
                } else {
                    ForEach(sellable) { item in
                        sellCard(item)
                    }
                }
            }
        }
    }

    private func buyCard(_ offer: MarketOffer) -> some View {
        let affordable = store.dust >= offer.buyPrice
        return card(
            item: offer.item,
            badge: "×\(offer.stock)",
            price: offer.buyPrice,
            priceTint: affordable ? Theme.accent : Theme.textSecondary,
            actionLabel: "Acheter",
            actionIcon: "cart.fill",
            actionTint: affordable ? Theme.accent : Theme.textSecondary,
            isEnabled: affordable
        ) {
            transact { try store.buy(offer.item) }
        }
    }

    private func sellCard(_ item: CatalogItem) -> some View {
        card(
            item: item,
            badge: "×\(store.ownedCount(for: item))",
            price: MarketPrice.sell(for: item.rarity),
            priceTint: Theme.accent,
            actionLabel: "Vendre",
            actionIcon: "cart.badge.plus",
            actionTint: Theme.danger,
            isEnabled: true
        ) {
            transact { try store.sell(item.id) }
        }
    }

    private func card(
        item: CatalogItem,
        badge: String,
        price: Int,
        priceTint: Color,
        actionLabel: String,
        actionIcon: String,
        actionTint: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                RarityBadge(rarity: item.rarity)
                Spacer(minLength: 4)
                Text(badge)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            ItemImageView(item: item, size: 56)

            Text(item.displayName)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)

            HStack(spacing: 4) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.caption2)
                Text("\(price)")
                    .font(Theme.mono(12, weight: .bold))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(priceTint)

            Button(action: action) {
                Label(actionLabel, systemImage: actionIcon)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glassProminent)
            .tint(actionTint)
            .disabled(!isEnabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(item.rarity.color.opacity(0.28), lineWidth: 0.7)
        }
    }

    private func transact(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch let error as AppError {
            errorMessage = error.errorDescription ?? "Transaction échouée."
        } catch {
            errorMessage = "Transaction échouée."
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .foregroundStyle(Theme.danger)
        .padding(Theme.spaceM)
        .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.danger.opacity(0.4), lineWidth: 0.6)
        }
        .transition(.opacity)
    }
}

/// Mode d'affichage du marché.
private enum MarketMode {
    case buy
    case sell
}
