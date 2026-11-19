import SwiftUI

struct BoostersView: View {
    @Environment(GameStore.self) private var store
    @State private var session: OpeningSession?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    content
                    if store.isOffline {
                        offlineBanner
                    }
                }
                .padding(16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await store.sync()
            }
        }
        .fullScreenCover(item: $session) { mode in
            OpeningView(session: mode)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MineMaster")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Ouvre. Collectionne. Fabrique.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 12)
            progressCard
        }
    }

    private var progressCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Collection")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(store.uniqueCount) / \(store.catalog.count)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                ProgressView(value: store.progress)
                    .tint(Theme.accent)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(store.uniqueCount) items sur \(store.catalog.count)")
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.catalog.isEmpty {
            VStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBooster()
                }
            }
        } else if let error = store.loadError {
            errorCard(error)
        } else {
            VStack(spacing: 14) {
                ForEach(Booster.allCases) { booster in
                    BoosterTile(booster: booster) {
                        open(booster)
                    }
                }
            }
        }
    }

    private func errorCard(_ error: AppError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text(error.errorDescription ?? "Erreur inconnue")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Réessayer") {
                Task { await store.sync() }
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Mode hors ligne — catalogue en cache")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .frame(maxWidth: .infinity)
    }

    private func open(_ booster: Booster) {
        let results = store.open(booster)
        guard !results.isEmpty else { return }
        session = OpeningSession(booster: booster, results: results)
    }
}

struct BoosterTile: View {
    let booster: Booster
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: booster.symbol)
                    .font(.title2)
                    .foregroundStyle(booster.tint)
                Spacer()
                Text("\(booster.cardCount) cartes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(booster.displayName)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)

            Text(booster.subtitle)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(booster.guaranteeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(booster.tint)
                Spacer()
                Button("Ouvrir", action: action)
                    .buttonStyle(.glassProminent)
                    .tint(booster.tint)
                    .accessibilityHint("Ouvre le booster et révèle cinq items")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(
            .regular.tint(booster.tint.opacity(0.20)),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
}
