import SwiftData
import SwiftUI

/// Point d'entrée de l'application Apple Watch.
@main
struct MineMasterWatchApp: App {
    @State private var store: GameStore?

    init() {
        #if DEBUG
        if UITestSupport.isEnabled, let store = UITestSupport.makeStore() {
            _store = State(initialValue: store)
            return
        }
        #endif

        if let container = try? GameContainer.make() {
            _store = State(initialValue: GameStore(container: container))
        } else {
            _store = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store {
                WatchRootView()
                    .environment(store)
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
