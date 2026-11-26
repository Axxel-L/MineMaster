import SwiftUI

/// Session d'ouverture propre à la montre.
struct WatchOpeningSession: Identifiable {
    let id = UUID()
    let booster: Booster
    let kind: BoosterKind
    let results: [DrawResult]
}

/// Pack scellé puis révélation carte par carte sur la montre.
struct WatchPackOpeningView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchLink.self) private var link
    @Environment(\.dismiss) private var dismiss

    @State private var plan: OpeningPlan?
    @State private var session: WatchOpeningSession?
    @State private var errorMessage: String?
    @State private var isOpening = false

    init(plan: OpeningPlan? = nil) {
        _plan = State(initialValue: plan)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                if let session {
                    WatchOpeningView(session: session) {
                        dismiss()
                    }
                } else {
                    sealedContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fermer")
                    .accessibilityIdentifier("watch-close")
                }
            }
            .task {
                guard plan == nil else { return }
                await loadPlan()
            }
            .onChange(of: link.isLocked) { _, locked in
                if locked {
                    dismiss()
                }
            }
            .onDisappear {
                link.closeOpening()
            }
        }
    }

    private var sealedContent: some View {
        VStack(spacing: 10) {
            WatchBoosterArt(booster: plan?.booster ?? .rare, kind: plan?.kind)
            if let plan {
                Text("\(plan.booster.displayName) · \(plan.kind.displayName)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Button {
                Task { await openPack() }
            } label: {
                Label(
                    isOpening ? "Ouverture…" : "Ouvrir le pack",
                    systemImage: isOpening ? "hourglass" : "scissors"
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(plan?.kind.tint ?? Theme.copper)
            .disabled(!link.canPlay || isOpening)
            .accessibilityIdentifier("watch-pack-tear")
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            }
            if !link.canPlay {
                Text("Ouvre l'iPhone pour jouer.")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private func loadPlan() async {
        guard link.canPlay else {
            errorMessage = "Ouvre l'iPhone pour jouer."
            return
        }
        plan = await link.plan()
        if plan == nil {
            errorMessage = link.lastError ?? "Pack indisponible."
        }
    }

    private func openPack() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        if plan == nil {
            await loadPlan()
        }
        guard let plan else { return }
        guard let opened = await link.open(plan) else {
            errorMessage = link.lastError ?? "Ouverture impossible."
            return
        }
        guard let session = makeSession(opened) else {
            errorMessage = "Cartes indisponibles sur la montre."
            return
        }
        errorMessage = nil
        self.session = session
    }

    private func makeSession(_ opened: WatchOpenResult) -> WatchOpeningSession? {
        let byID = Dictionary(uniqueKeysWithValues: store.catalog.map { ($0.id, $0) })
        let results = opened.cards.compactMap { card in
            byID[card.itemID].map { DrawResult(item: $0, dust: card.dust, isNew: card.isNew) }
        }
        guard results.count == opened.cards.count,
              !results.isEmpty,
              let booster = opened.plan.booster,
              let kind = opened.plan.kind else {
            return nil
        }
        return WatchOpeningSession(booster: booster, kind: kind, results: results)
    }
}

/// Révélation des cinq cartes, puis passage à la suivante au second appui.
struct WatchOpeningView: View {
    let session: WatchOpeningSession
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var deck: RevealDeck

    init(session: WatchOpeningSession, onFinish: @escaping () -> Void) {
        self.session = session
        self.onFinish = onFinish
        _deck = State(initialValue: RevealDeck(count: session.results.count))
    }

    private var dustTotal: Int {
        session.results.enumerated()
            .filter { deck.revealed.contains($0.offset) }
            .reduce(0) { $0 + $1.element.dust }
    }

    private var newCount: Int {
        session.results.enumerated()
            .filter { deck.revealed.contains($0.offset) && $0.element.isNew }
            .count
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            TabView(selection: Binding(get: { deck.index }, set: { deck.select($0) })) {
                ForEach(Array(session.results.enumerated()), id: \.element.id) { position, result in
                    WatchRevealCard(
                        result: result,
                        position: position,
                        isRevealed: deck.revealed.contains(position)
                    ) {
                        handleTap(position)
                    }
                    .tag(position)
                }
            }
            .tabViewStyle(.verticalPage)
            pageDots
            bottomBar
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .sensoryFeedback(.success, trigger: deck.revealTick)
        .sensoryFeedback(.selection, trigger: deck.advanceTick)
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: session.kind.systemImage)
                    .font(.system(size: 8, weight: .bold))
                Text(session.kind.displayName.uppercased())
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.6)
                Spacer(minLength: 2)
                Text("\(deck.index + 1) / \(session.results.count)")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityIdentifier("watch-card-index")
            }
            .foregroundStyle(session.kind.tint)
            Text("\(deck.revealed.count) / \(session.results.count) révélées")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityIdentifier("watch-reveal-count")
        }
    }

    private var pageDots: some View {
        HStack(spacing: 4) {
            ForEach(session.results.indices, id: \.self) { position in
                Capsule()
                    .fill(
                        position == deck.index
                            ? session.results[position].item.rarity.color
                            : Theme.textSecondary.opacity(0.24)
                    )
                    .frame(width: position == deck.index ? 12 : 4, height: 4)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: deck.index)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if deck.allRevealed {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if newCount > 0 {
                        Text("+\(newCount) nouveaux")
                            .foregroundStyle(Theme.accent)
                    }
                    if dustTotal > 0 {
                        Text("+\(dustTotal) poussière")
                            .foregroundStyle(Rarity.epic.color)
                    }
                }
                .font(.system(size: 8, weight: .bold, design: .rounded))
                Button("Terminer", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("watch-finish")
            }
        } else {
            Text(deck.isCurrentRevealed ? "Touche encore pour avancer" : "Touche la carte")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 24)
        }
    }

    private func handleTap(_ position: Int) {
        if deck.revealed.contains(position) {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy) {
                deck.advance(from: position)
            }
        } else {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy) {
                deck.reveal(position)
            }
        }
    }
}
