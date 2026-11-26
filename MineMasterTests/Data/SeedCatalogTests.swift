import Foundation
import Testing
@testable import MineMaster

@MainActor
@Suite("Catalogue embarqué")
struct SeedCatalogTests {
    @Test("Le catalogue embarqué charge ses 515 items")
    func loadsAllItems() {
        let items = SeedCatalog.load(bundle: .main)

        #expect(items.count == 515)
        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test("Le catalogue contient des créatures, des livres et des blocs")
    func containsNewWorldContent() {
        let items = SeedCatalog.load(bundle: .main)

        #expect(items.contains { $0.category == .mob })
        #expect(items.contains { $0.id.hasPrefix("enchanted_book") })
        #expect(items.contains { $0.id == "creaking" })
    }

    @Test("Le catalogue expose les créatures et objets historiques")
    func containsHistoricalContent() {
        let items = SeedCatalog.load(bundle: .main)
        let ids = Set(items.map(\.id))

        for id in ["herobrine", "illusioner", "killer_bunny", "copper_golem", "horse_saddle", "camera"] {
            #expect(ids.contains(id), "Item historique absent: \(id)")
        }
        #expect(items.first { $0.id == "herobrine" }?.rarity == .legendary)
        #expect(items.first { $0.id == "glowing_obsidian" }?.rarity == .epic)
    }

    @Test("Chaque rendu historique respecte l'allowlist")
    func everyLegacyRenderIsAllowed() {
        for id in ["horse_saddle", "camera", "nether_reactor_core", "glowing_obsidian"] {
            let url = LegacyRenderAPI.url(for: id)
            #expect(url != nil, "Rendu historique absent: \(id)")
            #expect(url.map(ImagePolicy.isAllowed) == true)
        }
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
