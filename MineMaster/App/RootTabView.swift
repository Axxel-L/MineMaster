import SwiftUI

struct RootTabView: View {
    @Environment(GameStore.self) private var store
    @State private var selection = "packs"

    var body: some View {
        TabView(selection: $selection) {
            Tab("Packs", systemImage: "shippingbox.fill", value: "packs") {
                BoostersView()
            }
            Tab("Collection", systemImage: "square.grid.2x2.fill", value: "collection") {
                CollectionView()
            }
            Tab("Profil", systemImage: "chart.bar.fill", value: "profile") {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Theme.accent)
        .task {
            await store.bootstrap()
        }
    }
}
