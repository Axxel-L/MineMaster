import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("Catalogue embarqué")
struct SeedCatalogTests {
    @Test("Le catalogue embarqué charge ses 254 items")
    func loadsAllItems() {
        let items = SeedCatalog.load(bundle: .main)

        #expect(items.count == 254)
        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test("Le catalogue contient des créatures, des livres et des blocs")
    func containsNewWorldContent() {
        let items = SeedCatalog.load(bundle: .main)

        #expect(items.contains { $0.category == .mob })
        #expect(items.contains { $0.id.hasPrefix("enchanted_book") })
        #expect(items.contains { $0.id == "creaking" })
    }

    @Test("Chaque créature possède un rendu autorisé")
    func everyMobHasRender() {
        let mobs = SeedCatalog.load(bundle: .main).filter { $0.category == .mob }

        #expect(!mobs.isEmpty)
        for mob in mobs {
            let url = MobRenderAPI.url(for: mob.id)
            #expect(url != nil, "Rendu absent: \(mob.id)")
            #expect(url.map(ImagePolicy.isAllowed) == true)
        }
    }

    @Test("Chaque texture du catalogue produit une URL autorisée")
    func everyTextureIsAllowed() {
        let items = SeedCatalog.load(bundle: .main)

        for item in items {
            let url = ImagePolicy.url(for: item.texturePath)
            #expect(url != nil, "Texture invalide: \(item.texturePath)")
            #expect(url.map(ImagePolicy.isAllowed) == true)
        }
    }

    @Test("Les identifiants techniques deviennent des libellés lisibles")
    func prettyPrintsIdentifiers() {
        #expect(SeedCatalog.pretty("oak_log") == "Oak Log")
        #expect(SeedCatalog.pretty("diamond") == "Diamond")
    }
}
