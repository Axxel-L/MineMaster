import SwiftUI

struct CollectionView: View {
    @Environment(GameStore.self) private var store

    @State private var search = ""
    @State private var rarity: Rarity?
    @State private var category: ItemCategory?
    @State private var ownedOnly = false

    @Namespace private var zoom

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    private var filtered: [CatalogItem] {
        store.catalog.filter { item in
            let matchesRarity = rarity == nil || item.rarity == rarity
            let matchesCategory = category == nil || item.category == category
            let matchesOwned = !ownedOnly || store.ownedCount(for: item) > 0
            let matchesSearch = search.isEmpty
                || item.displayName.localizedCaseInsensitiveContains(search)
            return matchesRarity && matchesCategory && matchesOwned && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        summary
                        searchField
                        filters

                        if store.catalog.isEmpty && store.isLoading {
                            SkeletonGrid()
                        } else if filtered.isEmpty {
                            EmptyStateView(
                                icon: "magnifying-glass",
                                title: "Aucun item",
                                message: "Ajuste les filtres ou ouvre un booster pour compléter la collection."
                            )
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filtered) { item in
                                    cell(item)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Collection")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: CatalogItem.self) { item in
                ItemDetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: zoom))
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Items uniques",
                value: "\(store.uniqueCount)/\(store.catalog.count)",
                systemImage: "square.grid.2x2.fill"
            )
            StatCard(
                title: "Poussière",
                value: "\(store.dust)",
                systemImage: "circle.hexagongrid.fill",
                tint: Rarity.epic.color
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Rechercher un item", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: Capsule())
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "Possédés", isActive: ownedOnly, tint: Theme.accent) {
                    ownedOnly.toggle()
                }
                ForEach(Rarity.allCases) { value in
                    FilterChip(
                        title: value.displayName,
                        isActive: rarity == value,
                        tint: value.color
                    ) {
                        rarity = rarity == value ? nil : value
                    }
                }
                ForEach(ItemCategory.allCases) { value in
                    FilterChip(
                        title: value.displayName,
                        isActive: category == value,
                        tint: .white
                    ) {
                        category = category == value ? nil : value
                    }
                }
                if rarity != nil || category != nil || ownedOnly {
                    FilterChip(title: "Effacer", isActive: false, tint: .white) {
                        rarity = nil
                        category = nil
                        ownedOnly = false
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func cell(_ item: CatalogItem) -> some View {
        let count = store.ownedCount(for: item)
        return NavigationLink(value: item) {
            VStack(spacing: 8) {
                ItemImageView(item: item, size: 58)
                Text(item.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 5) {
                    Circle()
                        .fill(item.rarity.color)
                        .frame(width: 7, height: 7)
                    if count > 0 {
                        Text("×\(count)")
                            .font(.caption2.monospacedDigit().bold())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .glassEffect(
                .regular.tint(item.rarity.color.opacity(count > 0 ? 0.16 : 0.05)),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .opacity(count > 0 ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: item.id, in: zoom)
        .accessibilityLabel("\(item.displayName), \(item.rarity.displayName), \(count) possédés")
    }
}
