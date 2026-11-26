import SwiftData
import SwiftUI

/// Point d'entrée de l'application Apple Watch.
@main
struct MineMasterWatchApp: App {
    @State private var store: GameStore?
    @State private var link: WatchLink?

    init() {
        #if DEBUG
        if UITestSupport.isEnabled, let store = UITestSupport.makeStore() {
            _store = State(initialValue: store)
            _link = State(initialValue: WatchLink(store: store, mode: .local))
            return
        }
        #endif

        do {
            let container = try GameContainer.make()
            let store = GameStore(container: container, syncOnBootstrap: false)
            _store = State(initialValue: store)
            _link = State(initialValue: WatchLink(store: store, mode: .local))
        } catch {
            _store = State(initialValue: nil)
            _link = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store, let link {
                WatchRootView()
                    .environment(store)
                    .environment(link)
                    .preferredColorScheme(.dark)
            } else {
                WatchStorageErrorView()
                    .preferredColorScheme(.dark)
            }
        }
    }
}

struct WatchStorageErrorView: View {
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.copper)
                Text("Stockage indisponible")
                    .font(.headline)
                Text("Redémarre l'app.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.spaceS)
        }
    }
}
