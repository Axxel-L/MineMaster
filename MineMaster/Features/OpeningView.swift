import SwiftUI

struct OpeningSession: Identifiable {
    let id = UUID()
    let booster: Booster
    let kind: BoosterKind
    let results: [DrawResult]
}

/// Pack scellé, dézippé au doigt avant révélation des cartes.
///
/// - Authors: Axel L.
struct PackOpeningView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var session: OpeningSession?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ScreenBackground()

            if let session {
                OpeningView(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                sealedContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.35), value: session?.id)
        .onDisappear {
            store.endOpening()
        }
    }

    private var sealedContent: some View {
        VStack(spacing: Theme.spaceL) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PACK SCELLÉ")
                        .font(Theme.mono(9, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Pack Mystère")
                        .font(Theme.display(27))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Fermer")
            }
            .padding(.horizontal, Theme.spaceL)
            .padding(.top, Theme.spaceM)

            Spacer(minLength: Theme.spaceS)

            InteractiveBoosterPack(booster: .rare, kind: .mixed, title: "Pack Mystère", onOpened: openPack)
                .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spaceXL)
            }

            Spacer(minLength: Theme.spaceL)
        }
    }

    private func openPack() {
        guard let open = store.openRandom() else {
            errorMessage = "Impossible d'ouvrir ce pack. Vérifie que le catalogue est chargé."
            return
        }
        session = OpeningSession(booster: open.booster, kind: open.kind, results: open.results)
    }
}

/// Révélation manuelle des cartes, une carte par appui.
///
/// - Authors: Axel L.
struct OpeningView: View {
    let session: OpeningSession

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed: Set<Int> = []
    @State private var feedbackTick = 0
    @State private var index = 0

    private var allRevealed: Bool {
        revealed.count == session.results.count
    }

    private var dustTotal: Int {
        session.results.enumerated()
            .filter { revealed.contains($0.offset) }
            .reduce(0) { $0 + $1.element.dust }
    }

    private var newCount: Int {
        session.results.enumerated()
            .filter { revealed.contains($0.offset) }
            .filter { $0.element.isNew }
            .count
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: Theme.spaceM) {
                topBar

                TabView(selection: $index) {
                    ForEach(Array(session.results.enumerated()), id: \.element.id) { position, result in
                        RevealCard(
                            result: result,
                            isRevealed: revealed.contains(position),
                            reduceMotion: reduceMotion,
                            width: 300,
                            height: 430
                        ) {
                            reveal(position)
                        }
                        .frame(maxWidth: .infinity)
                        .tag(position)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.top, Theme.spaceM)
            .containerRelativeFrame([.horizontal, .vertical])
            .overlay(alignment: .bottom) {
                VStack(spacing: 12) {
                    pageDots
                    bottomBar
                }
                .padding(.bottom, Theme.spaceL)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: feedbackTick)
        .onDisappear {
            store.endOpening()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: session.kind.systemImage)
                        .font(.system(size: 9, weight: .bold))
                    Text("RÉVÉLATION · \(session.kind.displayName.uppercased())")
                        .font(Theme.mono(9, weight: .bold))
                        .tracking(1.6)
                }
                .foregroundStyle(session.kind.tint)
                Text("CARTE \(index + 1) / \(session.results.count)")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Text(revealed.isEmpty ? "Aucune révélée" : revealed.count == 1 ? "1 révélée" : "\(revealed.count) révélées")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .accessibilityLabel("Fermer")
        }
        .padding(.horizontal, Theme.spaceL)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(session.results.indices, id: \.self) { position in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        index = position
                    }
                } label: {
                    Capsule()
                        .fill(
                            position == index
                                ? session.results[position].item.rarity.color
                                : Theme.textSecondary.opacity(0.24)
                        )
                        .frame(width: position == index ? 22 : 7, height: 7)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Carte \(position + 1)")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if allRevealed {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    if newCount > 0 {
                        summaryPill("\(newCount) nouveaux", icon: "sparkles", tint: Theme.accent)
                    }
                    if dustTotal > 0 {
                        summaryPill("+\(dustTotal) poussière", icon: "circle.hexagongrid.fill", tint: Rarity.epic.color)
                    }
                }
                Button("Terminer") {
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .controlSize(.large)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Text(revealed.contains(index) ? "Glisse pour changer de carte" : "Touche la carte pour la révéler")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 44)
        }
    }

    private func summaryPill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(Theme.mono(10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func reveal(_ index: Int) {
        guard !revealed.contains(index) else { return }
        withAnimation(reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.62, dampingFraction: 0.76)) {
            _ = revealed.insert(index)
        }
        feedbackTick += 1
    }
}

/// Carte face cachée puis retournée au toucher.
///
/// - Authors: Axel L.
struct RevealCard: View {
    let result: DrawResult
    let isRevealed: Bool
    let reduceMotion: Bool
    var width: CGFloat = 238
    var height: CGFloat = 344
    let onTap: () -> Void

    private var glow: CGFloat {
        switch result.item.rarity {
        case .common: 0.10
        case .uncommon: 0.18
        case .rare: 0.34
        case .epic: 0.52
        case .legendary: 0.75
        }
    }

    private var revealScale: CGFloat {
        switch result.item.rarity {
        case .common: 1
        case .uncommon: 1.01
        case .rare: 1.025
        case .epic: 1.04
        case .legendary: 1.06
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                back
                    .opacity(isRevealed ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : (isRevealed ? 180 : 0)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.35
                    )

                front
                    .opacity(isRevealed ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : (isRevealed ? 0 : -180)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.35
                    )

                if isRevealed, result.item.rarity >= .rare {
                    ParticleBurst(rarity: result.item.rarity)
                        .frame(width: width * 1.5, height: height * 1.2)
                        .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(result.item.rarity.color.opacity(isRevealed ? glow : 0.10))
                    .blur(radius: isRevealed ? 26 : 12)
            }
            .glassEffect(
                .regular.tint(result.item.rarity.color.opacity(isRevealed ? 0.22 : 0.08)),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .scaleEffect(isRevealed ? revealScale : 0.96)
            .shadow(
                color: result.item.rarity.color.opacity(isRevealed ? glow : 0.08),
                radius: isRevealed ? 28 : 12
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? result.item.displayName : "Carte non révélée")
        .accessibilityValue(isRevealed ? "\(result.item.rarity.displayName), \(result.dust) poussière" : "Touche pour révéler")
        .accessibilityHint(isRevealed ? "" : "Révèle cette carte")
    }

    private var front: some View {
        VStack(spacing: 12) {
            HStack {
                RarityBadge(rarity: result.item.rarity)
                Spacer()
                Text(result.item.category.displayName.uppercased())
                    .font(Theme.mono(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            if result.item.category == .mob {
                MobSpecimen(item: result.item, size: width * 0.62)
            } else {
                ItemImageView(item: result.item, size: width * 0.52)
                    .shadow(color: result.item.rarity.color.opacity(0.45), radius: 18)
            }

            Text(result.item.displayName)
                .font(Theme.display(width * 0.09, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if result.isNew {
                    Label("NOUVEAU", systemImage: "sparkles")
                        .foregroundStyle(Theme.accent)
                }
                if result.dust > 0 {
                    Label("+\(result.dust)", systemImage: "circle.hexagongrid.fill")
                        .foregroundStyle(Rarity.epic.color)
                }
            }
            .font(Theme.mono(9, weight: .bold))
            .frame(height: 16)
        }
        .padding(width * 0.075)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var back: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 14) {
                HStack {
                    Text("SCELLÉ")
                        .font(Theme.mono(9, weight: .bold))
                        .tracking(1.4)
                    Spacer()
                    Text("?")
                        .font(Theme.mono(11, weight: .bold))
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 18)
                .padding(.top, 18)

                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.10))
                        .frame(width: width * 0.45, height: width * 0.45)
                    Circle()
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                        .frame(width: width * 0.45, height: width * 0.45)
                    Image(systemName: "cube.fill")
                        .font(.system(size: width * 0.18, weight: .light))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                }

                Text("TOUCHE POUR\nRÉVÉLER")
                    .font(.system(size: width * 0.045, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                CrimpedEdge()
                    .frame(width: 190, height: 8)
                    .clipped()
                    .padding(.bottom, 18)
                    .opacity(0.45)
            }
        }
    }
}
