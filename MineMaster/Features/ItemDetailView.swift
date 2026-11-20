import SwiftUI

struct ItemDetailView: View {
    let item: CatalogItem

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?

    private var count: Int { store.ownedCount(for: item) }
    private var offer: MarketOffer? { store.marketOffer(for: item.id) }
    private var canBuy: Bool { (offer?.stock ?? 0) > 0 }
    private var affordable: Bool { store.dust >= MarketPrice.buy(for: item.rarity) }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    infoCard
                    actionBar
                    marketNote
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") {
                    dismiss()
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            if item.category == .mob {
                MobSpecimen(item: item, size: 230)
            } else {
                ItemImageView(item: item, size: 150)
                    .shadow(color: item.rarity.color.opacity(0.4), radius: 24)
            }
            RarityBadge(rarity: item.rarity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(item.rarity.color.opacity(0.34), lineWidth: 0.8)
        }
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("Catégorie", value: item.category.displayName, icon: item.category.systemImage)
            divider
            infoRow("Rareté", value: item.rarity.displayName, icon: "sparkles")
            divider
            infoRow("Chance de tirage", value: String(format: "%.0f %%", item.rarity.baseWeight), icon: "percent")
            divider
            infoRow("Tirages sur cet appareil", value: "\(store.pullCount(for: item))", icon: "hand.tap")
            divider
            infoRow("Tirages mondiaux", value: "—", icon: "globe")
            divider
            infoRow("Prix d'achat", value: "\(MarketPrice.buy(for: item.rarity))", icon: "cart.fill")
            divider
            infoRow("Prix de revente", value: "\(MarketPrice.sell(for: item.rarity))", icon: "cart.badge.plus")
            divider
            infoRow("Stock marché", value: "\(offer?.stock ?? 0)", icon: "shippingbox.fill")
            divider
            infoRow("Quantité possédée", value: "\(count)", icon: "square.stack.3d.up.fill")
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        if canBuy || count > 0 {
            VStack(spacing: 10) {
                if canBuy {
                    actionButton(
                        title: "Acheter · \(MarketPrice.buy(for: item.rarity))",
                        systemImage: "cart.fill",
                        tint: affordable ? Theme.accent : Theme.textSecondary,
                        isEnabled: affordable
                    ) {
                        transact { try store.buy(item) }
                    }
                }
                if count > 0 {
                    actionButton(
                        title: "Vendre · +\(MarketPrice.sell(for: item.rarity))",
                        systemImage: "cart.badge.plus",
                        tint: Theme.danger,
                        isEnabled: true
                    ) {
                        transact { try store.sell(item.id) }
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.spaceM)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.6)
            }
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .disabled(!isEnabled)
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

    private var marketNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Theme.copper)
            Text("Transactions réelles contre de la poussière, enregistrées sur cet appareil.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.spaceM)
        .background(Theme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.5)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 0.5)
    }

    private func infoRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 11)
    }
}
