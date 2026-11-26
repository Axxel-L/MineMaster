import SwiftUI

/// Racine de navigation de la montre.
struct WatchRootView: View {
    @Environment(GameStore.self) private var store
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    @State private var showTutorial = false

    var body: some View {
        Group {
            if store.isBootstrapped {
                NavigationStack {
                    WatchHomeView()
                }
            } else {
                WatchLoadingView()
            }
        }
        .task {
            if !store.isBootstrapped {
                await store.bootstrap()
            }
        }
        .onChange(of: store.isBootstrapped, initial: true) { _, isReady in
            guard isReady, !store.catalog.isEmpty, !hasSeenTutorial else { return }
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
