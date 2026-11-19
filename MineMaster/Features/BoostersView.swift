import SwiftUI

/// Accueil : pack mystère, types possibles et progression.
///
/// - Authors: Axel L.
struct BoostersView: View {
    @Environment(GameStore.self) private var store

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
                        hero
                        typesPreview
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
            PackOpeningView()
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
            Text("Un pack mystère. Cinq pièces. Le monde décide de ta rareté.")
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
                    .fill(BoosterKind.mixed.tint.opacity(0.18))
                    .frame(width: 250, height: 250)
                    .blur(radius: 38)

                BoosterPackArt(booster: .rare, kind: .mixed, title: "Pack Mystère")
                    .scaleEffect(0.82)
                    .frame(width: 214, height: 296)
                    .rotation3DEffect(.degrees(-5), axis: (x: 0, y: 1, z: 0))
                    .rotationEffect(.degrees(-2))
                    .onTapGesture {
                        isPresentingPack = true
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Ouvre l'écran de déchirure")

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
            .tint(BoosterKind.mixed.tint)
            .disabled(store.isOpening)
            .accessibilityHint("Ouvre un pack mystère")
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var typesPreview: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            HStack {
                Text("PACKS PAR TYPE")
                    .font(Theme.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("TIRAGE ALÉATOIRE")
                    .font(Theme.mono(8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(BoosterKind.allCases.filter { $0 != .mixed }) { kind in
                        kindCard(kind)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func kindCard(_ kind: BoosterKind) -> some View {
        VStack(spacing: 10) {
            BoosterPackArt(booster: .rare, kind: kind)
                .scaleEffect(0.43)
                .frame(width: 108, height: 151)
                .accessibilityHidden(true)

            HStack(spacing: 5) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(kind.packLabel)
                    .font(Theme.mono(9, weight: .bold))
                    .tracking(0.8)
            }
            .foregroundStyle(kind.tint)
        }
        .frame(width: 128)
        .padding(.vertical, 12)
        .background(kind.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(kind.tint.opacity(0.30), lineWidth: 0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pack \(kind.displayName)")
        .accessibilityValue(kind.subtitle)
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
