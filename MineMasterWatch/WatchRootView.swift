import SwiftUI

/// Racine de navigation de la montre.
struct WatchRootView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchLink.self) private var link
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    @State private var showTutorial = false

    var body: some View {
        Group {
            if store.isBootstrapped {
                if link.isLocked {
                    WatchLockedView()
                } else {
                    NavigationStack {
                        WatchHomeView()
                    }
                }
            } else {
                WatchLoadingView()
            }
        }
        .task {
            link.start()
            if !store.isBootstrapped {
                await store.bootstrap()
            }
            link.applyPending()
        }
        .onChange(of: store.isBootstrapped, initial: true) { _, isReady in
            guard isReady, !link.isLocked, !store.catalog.isEmpty, !hasSeenTutorial else { return }
            showTutorial = true
        }
        .sheet(isPresented: $showTutorial) {
            WatchTutorialView {
                hasSeenTutorial = true
                showTutorial = false
            }
        }
        .tint(Theme.accent)
    }
}

/// Écran affiché quand l'iPhone a fermé la session du compte.
struct WatchLockedView: View {
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.copper)
                Text("Compte requis")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Ouvre l'iPhone et connecte-toi pour retrouver ta collection.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
        }
    }
}
