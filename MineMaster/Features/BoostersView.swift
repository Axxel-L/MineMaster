import SwiftUI

/// Accueil : choix du pack, pack scellé et progression.
///
/// - Authors: Axel L.
struct BoostersView: View {
    @Environment(GameStore.self) private var store

    @State private var selected: Booster = .common
    @State private var isPresentingPack = false

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceL) {
                    masthead
                    if store.isLoading && store.catalog.isEmpty {
                        SkeletonBooster()
                        SkeletonBooster()
                    } else if let error = store.loadError {
                        errorCard(error)
                    } else {
                        selector
                        hero
                        collectionLedger
                    }
                    if store.isOffline {
                        offlineBanner
                    }
                }
                .padding(.horizontal, Theme.spaceM)
                .padding(.top, Theme.spaceM)
                .padding(.bottom, 160)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await store.sync()
            }
        }
        .fullScreenCover(isPresented: $isPresentingPack) {
            PackOpeningView(booster: selected)
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LE COFFRE")
                        .font(Theme.mono(9, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.textSecondary)
                    Text("MineMaster")
                        .font(Theme.display(38, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                dustPill
            }
            Text("Ouvre un pack. Révèle cinq pièces. Complète le monde.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dustPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.caption)
            Text("\(store.dust)")
                .font(Theme.mono(13, weight: .bold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.28), lineWidth: 0.6))
        .accessibilityLabel("\(store.dust) poussière")
    }

    private var hero: some View {
        VStack(spacing: Theme.spaceL) {
            ZStack {
                Circle()
                    .fill(selected.tint.opacity(0.18))
                    .frame(width: 250, height: 250)
                    .blur(radius: 38)

                BoosterPackArt(booster: selected)
                    .scaleEffect(0.82)
                    .frame(width: 214, height: 296)
                    .rotation3DEffect(.degrees(-5), axis: (x: 0, y: 1, z: 0))
                    .rotationEffect(.degrees(-2))
                    .onTapGesture {
                        isPresentingPack = true
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Ouvre l'écran de dézippage")

            }
            .frame(height: 306)

            Button {
                isPresentingPack = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "scissors")
                    Text("Déchirer le pack")
                        .font(Theme.mono(11, weight: .bold))
                        .tracking(1.1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.glassProminent)
            .tint(selected.tint)
            .disabled(store.isOpening)
            .accessibilityHint("Ouvre \(selected.displayName)")
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var selector: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            Text("CHOISIS TON PACK")
                .font(Theme.mono(10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: Theme.spaceS) {
                ForEach(Booster.allCases) { booster in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            selected = booster
                        }
                    } label: {
                        MiniBooster(booster: booster, isSelected: selected == booster)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == booster ? .isSelected : [])
                }
            }
        }
    }

    private var collectionLedger: some View {
        VStack(spacing: 0) {
            ledgerRow(
                title: "Collection",
                value: "\(store.uniqueCount) / \(store.catalog.count)",
                icon: "square.grid.2x2.fill",
                tint: Theme.moss
            )
            divider
            ledgerRow(
                title: "Ouvertures",
                value: "\(store.totalOpened)",
                icon: "shippingbox.fill",
                tint: Theme.copper
            )
            divider
            progressRow
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private func ledgerRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.mono(13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(16)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progression du monde")
                    .font(Theme.mono(9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(store.progress * 100)) %")
                    .font(Theme.mono(11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            ProgressView(value: store.progress)
                .progressViewStyle(.linear)
                .tint(Theme.accent)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(store.uniqueCount) items sur \(store.catalog.count)")
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("MODE HORS LIGNE · CATALOGUE EN CACHE")
                .font(Theme.mono(9, weight: .bold))
                .tracking(1.1)
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5))
        .frame(maxWidth: .infinity)
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
        .padding(Theme.spaceL)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }
}

private struct MiniBooster: View {
    let booster: Booster
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: booster.foilColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                CrimpedEdge()
                    .frame(width: 46, height: 8)
                    .clipped()
                    .offset(y: -18)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.black.opacity(0.5))
                    .frame(width: 28, height: 4)
                    .offset(y: 20)
            }
            .frame(height: 62)

            Text(booster.displayName)
                .font(Theme.mono(9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Theme.surfaceRaised : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(isSelected ? booster.tint.opacity(0.8) : Theme.stroke, lineWidth: isSelected ? 1.2 : 0.5)
        }
    }
}
