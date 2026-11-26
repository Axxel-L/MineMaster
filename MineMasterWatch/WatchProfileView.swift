import SwiftUI

/// Profil compact : progression, titre, renaissance et crédits.
struct WatchProfileView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchLink.self) private var link

    @State private var confirmRebirth = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Gauge(value: store.progress) {
                    Text("Progression")
                } currentValueLabel: {
                    Text("\(Int(store.progress * 100)) %")
                        .font(Theme.mono(11, weight: .bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                WatchInfoRow(title: "Items uniques", value: "\(store.uniqueCount) / \(store.catalog.count)")
                WatchInfoRow(title: "Ouvertures", value: "\(link.totalOpened)")
                WatchInfoRow(title: "Poussière", value: "\(store.dust)", tint: Theme.accent)
                WatchInfoRow(title: "Achats", value: "\(store.marketPurchases)")
                WatchInfoRow(title: "Ventes", value: "\(store.marketSales)")
                WatchInfoRow(title: "iPhone", value: link.isReachable ? "Connecté" : "Hors ligne")
            }

            Section("Communauté") {
                WatchInfoRow(
                    title: "Tirages",
                    value: link.globalLoaded ? "\(link.globalPulls)" : "—",
                    tint: Theme.accent
                )
                WatchInfoRow(
                    title: "Échanges",
                    value: link.globalLoaded ? "\(link.globalTrades)" : "—",
                    tint: Theme.copper
                )
                Button {
                    Task { await refreshCommunity() }
                } label: {
                    Label(isRefreshing ? "Actualisation…" : "Actualiser", systemImage: "arrow.clockwise")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                }
                .disabled(!link.canPlay || isRefreshing)
                .accessibilityIdentifier("watch-refresh-community")
            }

            Section("Titre") {
                HStack(spacing: 8) {
                    Image(systemName: store.explorerTitle.systemImage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(store.explorerTitle.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.explorerTitle.displayName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text(store.explorerTitle.subtitle)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                }
                .accessibilityIdentifier("watch-explorer-title")
            }

            Section("Renaissance") {
                Text("Niveau \(store.rebirthLevel)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("watch-rebirth-level")
                WatchInfoRow(
                    title: "Légendaire",
                    value: String(format: "+%.0f %%", store.rebirthBoost.legendaryBonus * 100),
                    tint: Rarity.legendary.color
                )
                WatchInfoRow(
                    title: "Épique",
                    value: String(format: "+%.0f %%", store.rebirthBoost.epicBonus * 100),
                    tint: Rarity.epic.color
                )
                WatchInfoRow(
                    title: "Poussière",
                    value: String(format: "+%.0f %%", store.rebirthBoost.dustBonus * 100),
                    tint: Theme.accent
                )
                if store.canRebirth {
                    Button {
                        confirmRebirth = true
                    } label: {
                        Label("Renaître", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .tint(Theme.copper)
                    .disabled(!link.canPlay)
                    .accessibilityIdentifier("watch-rebirth")
                } else {
                    Text("Encore \(Rebirth.remaining(uniqueCount: store.uniqueCount)) items différents")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                if !link.canPlay {
                    Text("Lecture seule : ouvre l'iPhone pour renaître.")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Section {
                NavigationLink {
                    WatchLegalView()
                } label: {
                    Label("Licences", systemImage: "doc.text.fill")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                WatchInfoRow(
                    title: "Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.danger)
            }
        }
        .navigationTitle("Profil")
        .task {
            if link.canPlay, !link.globalLoaded {
                await refreshCommunity()
            }
        }
        .confirmationDialog(
            "Renaître ?",
            isPresented: $confirmRebirth,
            titleVisibility: .visible
        ) {
            Button("Renaître", role: .destructive) {
                Task { await rebirth() }
            }
            .accessibilityIdentifier("watch-confirm-rebirth")
        } message: {
            Text("Collection et poussière remises à zéro. Les boosts restent acquis.")
        }
    }

    private func refreshCommunity() async {
        isRefreshing = true
        defer { isRefreshing = false }
        errorMessage = await link.refreshCommunity()
    }

    private func rebirth() async {
        errorMessage = await link.rebirth()
    }
}

/// Crédits et mentions légales sur la montre.
struct WatchLegalView: View {
    private let entries = [
        ("MineMaster", "Projet pédagogique non commercial"),
        ("Swift", "Apache 2.0 · Apple"),
        ("SwiftUI, SwiftData", "SDK watchOS · Apple"),
        ("Heroicons", "MIT · Tailwind Labs"),
        ("minecraft-data", "MIT · PrismarineJS"),
        ("Minecraft", "Mojang · Microsoft"),
        ("Minecraft Wiki", "CC BY-NC-SA 3.0"),
        ("SF Symbols", "Apple")
    ]

    var body: some View {
        List {
            ForEach(entries, id: \.0) { name, license in
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(license)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Text("Textures chargées depuis un CDN public, jamais copiées dans l'app. Aucune donnée personnelle collectée.")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .navigationTitle("Licences")
    }
}
