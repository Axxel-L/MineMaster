import SwiftUI

struct RootTabView: View {
    @Environment(GameStore.self) private var store
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    @State private var selection = "packs"
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            if store.isBootstrapped {
                TabView(selection: $selection) {
                    BoostersView()
                        .tabItem {
                            Label {
                                Text("Boosters")
                            } icon: {
                                Image("gift")
                                    .renderingMode(.template)
                            }
                        }
                        .tag("packs")
                    MarketView()
                        .tabItem {
                            Label {
                                Text("Marché")
                            } icon: {
                                Image(systemName: "cart.fill")
                                    .renderingMode(.template)
                            }
                        }
                        .tag("market")
                    CollectionView()
                        .tabItem {
                            Label {
                                Text("Collection")
                            } icon: {
                                Image("squares-2x2")
                                    .renderingMode(.template)
                            }
                        }
                        .tag("collection")
                    ProfileView()
                        .tabItem {
                            Label {
                                Text("Profil")
                            } icon: {
                                Image("chart-bar")
                                    .renderingMode(.template)
                            }
                        }
                        .tag("profile")
                }
                .tint(Theme.accent)
                .transition(.opacity)
            } else {
                LaunchLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: store.isBootstrapped)
        .task {
            if !store.isBootstrapped {
                await store.bootstrap()
            }
        }
        .onChange(of: store.isBootstrapped, initial: true) { _, ready in
            guard ready, !store.catalog.isEmpty, !hasSeenTutorial else { return }
            showTutorial = true
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView {
                hasSeenTutorial = true
                showTutorial = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.background)
        }
    }
}
