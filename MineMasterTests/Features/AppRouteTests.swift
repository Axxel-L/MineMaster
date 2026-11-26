import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("Liens profonds")
struct AppRouteTests {
    @Test("Un lien widget ouvre l'onglet des boosters")
    func opensBoosters() {
        let route = AppRoute()

        route.handle(URL(string: "minemaster://boosters")!)

        #expect(route.selectedTab == "packs")
    }

    @Test("Un lien profil ouvre le profil")
    func opensProfile() {
        let route = AppRoute()

        route.handle(URL(string: "minemaster://profile")!)

        #expect(route.selectedTab == "profile")
    }

    @Test("Un schéma ou un hôte inconnu ne change pas l'onglet")
    func ignoresUnknownLinks() {
        let route = AppRoute()
        route.selectedTab = "collection"

        route.handle(URL(string: "https://example.com/profile")!)
        route.handle(URL(string: "minemaster://inconnu")!)

        #expect(route.selectedTab == "collection")
    }
}
