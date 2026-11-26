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
    }

    var body: some Scene {
        WindowGroup {
            if let store {
                RootTabView()
                    .environment(store)
                    .environment(AuthSession())
                    .environment(
                        ProgressSync(
                            uid: "ui-test-account",
                            transport: .init(fetch: { nil }, push: { _ in })
                        )
                    )
                    .environment(
                        GlobalStatsSync(
                            transport: .init(
                                fetch: { [String: GlobalItemStats]() },
                                push: { _ in }
                            )
                        )
                    )
                    .preferredColorScheme(.dark)
            } else {
                RootGateView()
                    .preferredColorScheme(.dark)
            }
        }
    }
}
