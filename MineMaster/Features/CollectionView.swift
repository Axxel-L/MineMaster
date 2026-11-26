import SwiftUI

struct CollectionView: View {
    @Environment(GameStore.self) private var store

    @State private var search = ""
    @State private var rarity: Rarity?
    @State private var category: ItemCategory?
    @State private var ownedOnly = false
    @State private var selectedItem: CatalogItem?

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
        let items = filtered

        return NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        summary
                        searchField
                        filters

                        if store.catalog.isEmpty && store.isLoading {
                            SkeletonGrid()
                        } else if items.isEmpty {
                            EmptyStateView(
                                icon: "magnifying-glass",
                                title: "Aucun résultat",
                                message: "Modifie la recherche ou les filtres, ou ouvre un pack pour compléter ta collection."
                            )
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items) { item in
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
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    ItemDetailView(item: item)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(Theme.background)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Items découverts",
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
                .accessibilityIdentifier("search-field")
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
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5))
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
        return Button {
            selectedItem = item
        } label: {
            VStack(spacing: 8) {
                ItemImageView(item: item, size: 58)
                Text(item.displayName)
                    .font(Theme.mono(9, weight: .semibold))
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
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .strokeBorder(
                        count > 0 ? item.rarity.color.opacity(0.34) : Theme.stroke,
                        lineWidth: count > 0 ? 0.9 : 0.5
                    )
            }
            .opacity(count > 0 ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("item-\(item.id)")
        .accessibilityLabel("\(item.displayName), \(item.rarity.displayName), \(count) possédés")
    }
}
