import SwiftUI

struct RootTabView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        TabView {
            Tab("Boosters", systemImage: "shippingbox.fill") {
                BoostersView()
            }
            Tab("Collection", systemImage: "square.grid.2x2.fill") {
                CollectionView()
            }
            Tab("Profil", systemImage: "chart.bar.fill") {
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
