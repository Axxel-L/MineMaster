import SwiftUI

struct OpeningSession: Identifiable {
    let id = UUID()
    let booster: Booster
    let results: [DrawResult]
}

struct OpeningView: View {
    let session: OpeningSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed = 0
    @State private var selected = 0
    @State private var finished = false
    @State private var skipped = false

    private var current: DrawResult? {
        guard !session.results.isEmpty else { return nil }
        return session.results[min(selected, session.results.count - 1)]
    }

    private var newCount: Int { session.results.filter(\.isNew).count }
    private var dustTotal: Int { session.results.reduce(0) { $0 + $1.dust } }

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 16) {
                topBar
                Spacer(minLength: 4)

                if let current {
                    RevealCard(result: current, isRevealed: selected < revealed)
                        .id(current.id)
                }

                Spacer(minLength: 4)
                thumbnails
                bottomBar
            }
            .padding(20)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: revealed)
        .sensoryFeedback(.success, trigger: finished)
        .task {
            await runReveal()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.booster.displayName)
                    .font(.headline)
                Text("\(revealed) / \(session.results.count) révélés")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Fermer")
        }
    }

    private var thumbnails: some View {
        HStack(spacing: 8) {
            ForEach(Array(session.results.enumerated()), id: \.element.id) { index, result in
                Button {
                    guard index < revealed else { return }
                    selected = index
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        if index < revealed {
                            ItemImageView(item: result.item, size: 28)
                        } else {
                            Image(systemName: "questionmark")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(width: 46, height: 58)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                index == selected ? result.item.rarity.color : Theme.stroke,
                                lineWidth: index == selected ? 1.6 : 0.5
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(index < revealed ? result.item.displayName : "Carte non révélée")
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if finished {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
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
            Button("Tout révéler") {
                revealAll()
            }
            .buttonStyle(.glass)
            .disabled(session.results.isEmpty)
        }
    }

    private func summaryPill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private func runReveal() async {
        guard !session.results.isEmpty else {
            finished = true
            return
        }
        if reduceMotion {
            revealed = session.results.count
            selected = session.results.count - 1
            finished = true
            return
        }

        try? await Task.sleep(for: .milliseconds(600))
        for index in session.results.indices {
            if Task.isCancelled || skipped { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                revealed = index + 1
                selected = index
            }
            if index < session.results.count - 1 {
                try? await Task.sleep(for: .milliseconds(950))
            }
        }
        if !skipped {
            withAnimation(.easeOut(duration: 0.25)) {
                finished = true
            }
        }
    }

    private func revealAll() {
        skipped = true
        withAnimation(.easeOut(duration: 0.25)) {
            revealed = session.results.count
            selected = session.results.count - 1
            finished = true
        }
    }
}

struct RevealCard: View {
    let result: DrawResult
    let isRevealed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(result.item.rarity.gradient)

            if isRevealed {
                front
                    .transition(.opacity)
            } else {
                back
            }
        }
        .frame(width: 270, height: 360)
        .glassEffect(
            .regular.tint(result.item.rarity.color.opacity(0.22)),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .rotation3DEffect(
            .degrees(isRevealed ? 0 : 180),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.35
        )
        .shadow(
            color: result.item.rarity.color.opacity(isRevealed ? 0.45 : 0),
            radius: 28
        )
        .animation(.spring(response: 0.62, dampingFraction: 0.76), value: isRevealed)
    }

    private var front: some View {
        VStack(spacing: 12) {
            ItemImageView(item: result.item, size: 132)
            Text(result.item.displayName)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            RarityBadge(rarity: result.item.rarity)
            HStack(spacing: 8) {
                if result.isNew {
                    Label("Nouveau", systemImage: "sparkles")
                        .foregroundStyle(Theme.accent)
                }
                if result.dust > 0 {
                    Label("+\(result.dust)", systemImage: "circle.hexagongrid.fill")
                        .foregroundStyle(Rarity.epic.color)
                }
            }
            .font(.caption.weight(.semibold))
            .frame(height: 18)
        }
        .padding(20)
    }

    private var back: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.white.opacity(0.55))
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.18))
                .frame(width: 46, height: 4)
        }
    }
}
