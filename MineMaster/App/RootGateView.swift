import GoogleSignIn
import SwiftUI

/// Point d'entrée authentifié : configuration, connexion, puis application.
///
/// Aucune progression n'est créée avant une session valide. Chaque compte ouvre
/// son propre magasin SwiftData, et la synchronisation Firestore démarre une
/// fois le catalogue local prêt.
struct RootGateView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var session = AuthSession()
    @State private var store: GameStore?
    @State private var sync: ProgressSync?
    @State private var globalStats: GlobalStatsSync?
    @State private var storageError: AppError?
    @State private var watchBridge = WatchBridge()
    @State private var attempt = 0
    @State private var confirmReset = false

    private struct LoadKey: Hashable {
        let accountID: String?
        let attempt: Int
    }

    var body: some View {
        ZStack {
            switch session.phase {
            case .loading:
                LaunchLoadingView()
            case .unavailable(let error):
                UnavailableView(
                    title: "Accès indisponible",
                    error: error,
                    primary: ("Réessayer", { Task { await session.start() } }),
                    secondary: nil
                )
            case .signedOut:
                AuthView(session: session)
                    .transition(.opacity)
            case .signedIn:
                signedInContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .task {
            watchBridge.start()
            await session.start()
        }
        .task(id: LoadKey(accountID: session.account?.id, attempt: attempt)) { await prepare() }
        .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            sync?.retry()
            watchBridge.pushNow()
        }
        .confirmationDialog(
            "Réinitialiser le stockage local ?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Réinitialiser", role: .destructive) {
                guard let id = session.account?.id else { return }
                sync?.suspend()
                store?.onPersist = nil
                store?.onPulls = nil
                store?.onMarketTrade = nil
                sync = nil
                store = nil
                globalStats = nil
                watchBridge.lock()
                ProgressSync.clearMarkers(uid: id)
                try? AppPersistence.resetStore(for: id)
                attempt += 1
            }
        } message: {
            Text("Le fichier local de ce compte sera supprimé. La progression enregistrée sur Firestore sera rechargée à la reconnexion.")
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        if let store, let sync, let globalStats {
            RootTabView()
                .environment(store)
                .environment(session)
                .environment(sync)
                .environment(globalStats)
        } else if let storageError {
            UnavailableView(
                title: "Stockage local",
                error: storageError,
                primary: ("Réessayer", { attempt += 1 }),
                secondary: ("Réinitialiser le stockage", { confirmReset = true })
            )
        } else {
            LaunchLoadingView()
        }
    }

    private func prepare() async {
        guard let account = session.account else {
            sync?.suspend()
            store?.onPersist = nil
            store?.onPulls = nil
            store?.onMarketTrade = nil
            sync = nil
            store = nil
            globalStats = nil
            storageError = nil
            watchBridge.lock()
            return
        }
        if store != nil, sync?.accountID == account.id, storageError == nil { return }

        watchBridge.lock()
        sync?.suspend()
        store?.onPersist = nil
        store?.onPulls = nil
        store?.onMarketTrade = nil
        sync = nil
        store = nil
        globalStats = nil
        storageError = nil

        do {
            let container = try AppPersistence.container(for: account.id)
            guard !Task.isCancelled else { return }
            let accountStore = GameStore(container: container)
            await accountStore.bootstrap()
            guard !Task.isCancelled, session.account?.id == account.id else { return }

            let accountSync = ProgressSync(uid: account.id)
            accountSync.attach(
                snapshot: { [weak accountStore] in
                    accountStore?.progressSnapshot() ?? ProgressSnapshot.empty()
                },
                apply: { [weak accountStore] snapshot in
                    accountStore?.applyRemote(snapshot) ?? false
                }
            )
            let accountGlobal = GlobalStatsSync()
            accountStore.onPersist = { [weak accountSync, weak watchBridge] in
                accountSync?.markDirty()
                watchBridge?.schedulePush()
            }
            accountStore.onPulls = { [weak accountGlobal] ids in
                accountGlobal?.recordPulls(ids)
            }
            accountStore.onMarketTrade = { [weak accountGlobal] id in
                accountGlobal?.recordMarketTrade(id)
            }
            store = accountStore
            sync = accountSync
            globalStats = accountGlobal
            watchBridge.attach(store: accountStore, stats: accountGlobal)

            await accountSync.restore()
            Task {
                await accountGlobal.refresh()
                watchBridge.schedulePush()
            }
            guard !Task.isCancelled, session.account?.id == account.id else { return }
        } catch let error as AppError {
            storageError = error
            watchBridge.lock()
        } catch {
            storageError = .storageUnavailable
            watchBridge.lock()
        }
    }
}

/// Écran d'erreur bloquante avec une action de reprise et une action secondaire.
private struct UnavailableView: View {
    let title: String
    let error: AppError
    let primary: (String, () -> Void)
    let secondary: (String, () -> Void)?

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: Theme.spaceM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.danger)

                VStack(spacing: Theme.spaceXS) {
                    Text(title)
                        .font(Theme.display(24, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(error.errorDescription ?? "Réessaie dans un instant.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button(primary.0, action: primary.1)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, Theme.spaceL)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: Capsule())

                if let secondary {
                    Button(secondary.0, action: secondary.1)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(Theme.spaceL)
        }
    }
}
