import SwiftUI

struct ItemDetailView: View {
    let item: CatalogItem

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var count: Int { store.ownedCount(for: item) }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    infoCard
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
            infoRow("Taux de rareté", value: String(format: "%.0f %%", item.rarity.baseWeight), icon: "percent")
            divider
            infoRow("Tes tirages", value: "\(store.pullCount(for: item))", icon: "hand.tap")
            divider
            infoRow("Tirages joueurs", value: "—", icon: "globe")
            divider
            infoRow("Prix marché", value: "Bientôt", icon: "tag")
            divider
            infoRow("Poussière doublon", value: "+\(item.rarity.dustValue)", icon: "circle.hexagongrid.fill")
            divider
            infoRow("Possédés", value: "\(count)", icon: "square.stack.3d.up.fill")
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var marketNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Theme.copper)
            Text("Les tirages mondiaux et le prix du marché seront branchés avec le marché global. En attendant, « Tes tirages » reste local.")
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
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 11)
    }
}
