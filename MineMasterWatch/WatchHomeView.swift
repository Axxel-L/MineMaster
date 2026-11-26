import SwiftUI

/// Accueil compact : pack mystère, progression et raccourcis.
struct WatchHomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchLink.self) private var link

    @State private var plan: OpeningPlan?
    @State private var showPack = false
    @State private var showHelp = false
    @State private var isLoadingPlan = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                packCard
                progressCard
                NavigationLink {
                    WatchMarketView()
                } label: {
                    WatchDestinationRow(
                        icon: "cart.fill",
                        title: "Marché",
                        value: "\(availableOffers) offres",
                        tint: Theme.copper
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("watch-market-link")
                NavigationLink {
                    WatchCollectionView()
                } label: {
                    WatchDestinationRow(
                        icon: "square.grid.2x2.fill",
                        title: "Collection",
                        value: "\(store.uniqueCount)/\(store.catalog.count)",
                        tint: Theme.moss
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("watch-collection-link")
                NavigationLink {
                    WatchProfileView()
                } label: {
                    WatchDestinationRow(
                        icon: "chart.bar.fill",
                        title: "Profil",
                        value: store.explorerTitle.displayName,
                        tint: Theme.accent
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("watch-profile-link")
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }
                if !link.canPlay {
                    offlineBanner
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("MineMaster")
        .task {
            await loadPlan()
        }
        .onChange(of: link.isReachable) { _, reachable in
            guard reachable, plan == nil else { return }
            Task { await loadPlan() }
        }
        .sheet(isPresented: $showPack, onDismiss: {
            plan = nil
            Task { await loadPlan() }
        }) {
            WatchPackOpeningView(plan: plan)
        }
        .sheet(isPresented: $showHelp) {
            WatchTutorialView {
                showHelp = false
            }
        }
    }

    private var availableOffers: Int {
        store.marketOfferings.filter { $0.stock > 0 }.count
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("MineMaster")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            WatchDustPill(dust: store.dust)
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 10, weight: .black))
                    .frame(width: 26, height: 26)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .accessibilityLabel("Aide")
        }
    }

    private var packCard: some View {
        VStack(spacing: 8) {
            Button {
                Task { await presentPack() }
            } label: {
                WatchBoosterArt(booster: plan?.booster ?? .rare, kind: plan?.kind)
                    .accessibilityIdentifier("watch-pack-art")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Prépare et ouvre le pack")

            Button {
                Task { await presentPack() }
            } label: {
                Label(
                    isLoadingPlan ? "Préparation…" : "Ouvrir le pack",
                    systemImage: isLoadingPlan ? "hourglass" : "shippingbox.fill"
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.copper)
            .disabled(!link.canPlay || isLoadingPlan || store.catalog.isEmpty)
            .accessibilityIdentifier("watch-open-pack")

            HStack(spacing: 4) {
                Circle()
                    .fill(link.isLocal ? Theme.moss : (link.isReachable ? Theme.accent : Theme.copper))
                    .frame(width: 5, height: 5)
                Text(link.isLocal ? "Mode local" : (link.isReachable ? "iPhone connecté" : "Lecture seule"))
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var progressCard: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Progression", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 4)
                Text("\(Int(store.progress * 100)) %")
                    .font(Theme.mono(11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            ProgressView(value: store.progress)
                .tint(Theme.accent)
            HStack {
                Text("\(store.uniqueCount) items")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(link.totalOpened) packs")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var offlineBanner: some View {
        Label("Lecture seule : ouvre l'iPhone", systemImage: "iphone.slash")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .frame(maxWidth: .infinity)
    }

    private func loadPlan() async {
        guard link.canPlay, !store.catalog.isEmpty, !isLoadingPlan else { return }
        isLoadingPlan = true
        plan = await link.plan()
        isLoadingPlan = false
    }

    private func presentPack() async {
        guard link.canPlay else {
            errorMessage = "Ouvre l'iPhone pour jouer."
            return
        }
        if plan == nil {
            await loadPlan()
        }
        guard plan != nil else {
            errorMessage = link.lastError ?? "Pack indisponible."
            return
        }
        errorMessage = nil
        showPack = true
    }
}
