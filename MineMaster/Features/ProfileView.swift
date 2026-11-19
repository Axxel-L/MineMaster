import SwiftUI

struct ProfileView: View {
    @Environment(GameStore.self) private var store

    @State private var showCraft = false
    @State private var showLegal = false
    @State private var confirmReset = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        stats
                        craftButton
                        settings
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCraft) {
                CraftView()
            }
            .sheet(isPresented: $showLegal) {
                LegalView()
            }
            .confirmationDialog(
                "Réinitialiser la collection ?",
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive) {
                    store.reset()
                }
            } message: {
                Text("Toute la progression et la poussière seront perdues. Cette action est irréversible.")
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatCard(title: "Items uniques", value: "\(store.uniqueCount)", systemImage: "square.grid.2x2.fill")
            StatCard(title: "Ouvertures", value: "\(store.totalOpened)", systemImage: "shippingbox.fill", tint: Rarity.rare.color)
            StatCard(title: "Poussière", value: "\(store.dust)", systemImage: "circle.hexagongrid.fill", tint: Rarity.epic.color)
            StatCard(
                title: "Progression",
                value: "\(Int(store.progress * 100)) %",
                systemImage: "chart.line.uptrend.xyaxis",
                tint: Rarity.legendary.color
            )
        }
    }

    private var craftButton: some View {
        Button {
            showCraft = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.title3)
                    .foregroundStyle(Rarity.epic.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fabriquer un item")
                        .font(.subheadline.weight(.semibold))
                    Text("Dépense ta poussière pour compléter la collection")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .glassEffect(.regular.tint(Rarity.epic.color.opacity(0.14)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var settings: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Mentions légales et licences", icon: "doc.text.fill") {
                showLegal = true
            }
            Rectangle().fill(Theme.stroke).frame(height: 0.5).padding(.leading, 44)
            settingsRow(title: "Réinitialiser la collection", icon: "trash.fill", isDestructive: true) {
                confirmReset = true
            }
            Rectangle().fill(Theme.stroke).frame(height: 0.5).padding(.leading, 44)
            HStack {
                Image(systemName: "info.circle.fill")
                    .frame(width: 24)
                    .foregroundStyle(Theme.textSecondary)
                Text("Version")
                    .font(.subheadline)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func settingsRow(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(isDestructive ? .red : Theme.textSecondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isDestructive ? .red : Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CraftView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var craftedTick = 0

    private var available: [CatalogItem] {
        store.catalog.filter { store.ownedCount(for: $0) == 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        balance

                        if available.isEmpty {
                            EmptyStateView(
                                icon: "trophy",
                                title: "Collection complète",
                                message: "Tu possèdes déjà tous les items du catalogue."
                            )
                        } else {
                            ForEach(Rarity.allCases) { rarity in
                                let items = available.filter { $0.rarity == rarity }
                                if !items.isEmpty {
                                    section(rarity: rarity, items: items)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Fabriquer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.success, trigger: craftedTick)
        }
    }

    private var balance: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.title2)
                .foregroundStyle(Rarity.epic.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.dust) poussière")
                    .font(.headline)
                    .contentTransition(.numericText())
                Text("Gagnée en obtenant des doublons")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .glassEffect(.regular.tint(Rarity.epic.color.opacity(0.14)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func section(rarity: Rarity, items: [CatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(rarity.color).frame(width: 8, height: 8)
                Text(rarity.displayName)
                    .font(.subheadline.weight(.bold))
                Text("\(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: CatalogItem) -> some View {
        let canAfford = store.dust >= item.rarity.craftCost
        return HStack(spacing: 12) {
            ItemImageView(item: item, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("\(item.rarity.craftCost) poussière")
                    .font(.caption)
                    .foregroundStyle(canAfford ? Theme.textSecondary : .red.opacity(0.8))
            }
            Spacer()
            Button("Fabriquer") {
                if store.craft(item) {
                    craftedTick += 1
                }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(!canAfford)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        section(
                            title: "MineMaster",
                            text: "Application pédagogique de collection d'items Minecraft. Projet non commercial, non affilié à Mojang Studios ni à Microsoft."
                        )
                        section(
                            title: "Icônes",
                            text: "Heroicons 2.2.0, © Tailwind Labs, sous licence MIT. Les icônes système proviennent de SF Symbols (Apple)."
                        )
                        section(
                            title: "Textures Minecraft",
                            text: "Textures chargées à l'exécution depuis un CDN public, non redistribuées dans l'application. Minecraft est une marque de Mojang Studios."
                        )
                        section(
                            title: "Données",
                            text: "Aucune donnée personnelle n'est collectée ni transmise. La progression reste stockée localement sur l'appareil."
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Licences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
