import SwiftData
import SwiftUI

@main
struct MineMasterApp: App {
    @State private var store: GameStore?

    init() {
        #if DEBUG
        if UITestSupport.isEnabled, let store = UITestSupport.makeStore() {
            _store = State(initialValue: store)
            return
        }
        #endif

        let schema = Schema([
            CatalogItemRecord.self,
            CollectionRecord.self,
            PlayerRecord.self,
            OpeningRecord.self,
            MarketListingRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            _store = State(initialValue: GameStore(container: container))
        } else {
            _store = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store {
                RootTabView()
                    .environment(store)
                    .preferredColorScheme(.dark)
            } else {
                LaunchErrorView()
                    .preferredColorScheme(.dark)
            }
        }
    }
}

struct LaunchErrorView: View {
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Stockage indisponible")
                    .font(.headline)
                Text("Redémarre l'application pour réessayer.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(24)
        }
    }
}
