import SwiftUI

/// Accueil : ouverture de packs et progression.
///
/// - Authors: Axel L.
struct BoostersView: View {
    @Environment(GameStore.self) private var store
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    @State private var isPresentingPack = false
    @State private var showHelp = false
    @State private var plan: OpeningPlan?

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
            PackOpeningView(plan: plan)
        }
        .sheet(isPresented: $showHelp) {
            TutorialView {
                hasSeenTutorial = true
                showHelp = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.background)
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("MineMaster")
                    .font(Theme.display(38, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    dustPill
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Theme.surface, in: Circle())
                            .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Aide")
                }
            }
            Text("Ouvre un pack, découvre 5 cartes et complète ta collection.")
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

    private func presentPack() {
        plan = store.planOpening()
        isPresentingPack = true
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
                        presentPack()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Ouvre l'écran de déchirure")

            }
            .frame(height: 306)

            Button {
                presentPack()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                    Text("Ouvrir un pack")
                        .font(.headline)
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

    private var collectionLedger: some View {
        VStack(spacing: 0) {
            ledgerRow(
                title: "Collection",
                value: "\(store.uniqueCount) / \(store.catalog.count)",
                icon: "squares-2x2",
                tint: Theme.moss
            )
            divider
            ledgerRow(
                title: "Ouvertures",
                value: "\(store.totalOpened)",
                icon: "gift",
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
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(16)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progression")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(store.progress * 100)) %")
                    .font(.subheadline.weight(.semibold))
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
            Text("Hors ligne · catalogue enregistré")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
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
