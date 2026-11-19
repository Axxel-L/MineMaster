import SwiftUI

struct ItemDetailView: View {
    let item: CatalogItem

    @Environment(GameStore.self) private var store
    @State private var crafted = false

    private var count: Int { store.ownedCount(for: item) }
    private var shortfall: Int { max(0, item.rarity.craftCost - store.dust) }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    infoCard
                    craftSection
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: crafted)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ItemImageView(item: item, size: 150)
                .shadow(color: item.rarity.color.opacity(0.4), radius: 24)
            RarityBadge(rarity: item.rarity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassEffect(
            .regular.tint(item.rarity.color.opacity(0.20)),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("Catégorie", value: item.category.displayName, icon: item.category.systemImage)
            divider
            infoRow("Rareté", value: item.rarity.displayName, icon: "sparkles")
            divider
            infoRow("Chance de base", value: "\(Int(item.rarity.baseWeight)) %", icon: "percent")
            divider
            infoRow("Possédés", value: "\(count)", icon: "square.stack.3d.up.fill")
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var craftSection: some View {
        if count > 0 {
            Label("Déjà dans ta collection", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            VStack(spacing: 10) {
                Button {
                    crafted = store.craft(item)
                } label: {
                    Label("Fabriquer · \(item.rarity.craftCost) poussière", systemImage: "hammer.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(item.rarity.color)
                .controlSize(.large)
                .disabled(shortfall > 0)

                if shortfall > 0 {
                    Text("Il te manque \(shortfall) poussière. Ouvre des boosters pour en gagner.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
