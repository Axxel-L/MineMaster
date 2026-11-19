import Foundation
import Testing
@testable import MineMaster

@Suite("Politique des images")
struct ImagePolicyTests {
    @Test("Les chemins item et block acceptent minuscules, chiffres et underscore")
    func acceptsValidPaths() {
        let paths = ["item/diamond.png", "block/oak_log.png", "item/compass_00.png", "entity/zombie/zombie.png", "entity/witch.png"]

        for path in paths {
            let url = ImagePolicy.url(for: path)
            #expect(url != nil)
            #expect(url.map(ImagePolicy.isAllowed) == true)
        }
    }

    @Test("Les chemins hors contrat sont refusés")
    func rejectsInvalidPaths() {
        let paths = [
            "",
            "item/Diamond.png",
            "item/diamond.jpg",
            "item/diamond.png?x=1",
            "item/diamond.png#fragment",
            "item/../secret.png",
            "../item/diamond.png",
            "item/dia-mond.png",
            "item//diamond.png",
            "https://cdn.jsdelivr.net/item/diamond.png",
            "item/diamond.png/",
            "entity/../zombie.png",
            "entity/zombie/../diamond.png",
            "entity/Zombie/zombie.png",
            "entity/zombie/zombie.jpg"
        ]

        for path in paths {
            #expect(ImagePolicy.url(for: path) == nil)
        }
    }

    @Test("Les rendus de créatures de Minecraft Wiki sont autorisés")
    func acceptsMobRenders() {
        let render = URL(string: "https://minecraft.wiki/images/Panda_JE1_BE1.png")!
        let animated = URL(string: "https://minecraft.wiki/images/Warden.gif")!
        let webp = URL(string: "https://minecraft.wiki/images/Breeze_BE1_JE2.webp")!

        #expect(ImagePolicy.isAllowed(render))
        #expect(ImagePolicy.isAllowed(animated))
        #expect(ImagePolicy.isAllowed(webp))
        #expect(!ImagePolicy.isAllowed(URL(string: "http://minecraft.wiki/images/Panda_JE1_BE1.png")!))
        #expect(!ImagePolicy.isAllowed(URL(string: "https://minecraft.wiki/images/../secret.png")!))
        #expect(!ImagePolicy.isAllowed(URL(string: "https://minecraft.wiki/images/Panda_JE1_BE1.png?x=1")!))
    }

    @Test("Seules les URLs HTTPS du CDN sans query ni fragment sont autorisées")
    func rejectsForeignURLs() {
        let valid = ImagePolicy.url(for: "item/diamond.png")!
        #expect(ImagePolicy.isAllowed(valid))

        let invalid = [
            URL(string: "http://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/item/diamond.png")!,
            URL(string: "https://evil.example/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/item/diamond.png")!,
            URL(string: "https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/other/diamond.png")!,
            URL(string: "https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/item/diamond.png?x=1")!,
            URL(string: "https://cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/item/diamond.png#fragment")!,
            URL(string: "https://cdn.jsdelivr.net:8443/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/item/diamond.png")!,
            URL(string: "https://user@cdn.jsdelivr.net/gh/InventivetalentDev/minecraft-assets@1.21.4/assets/minecraft/textures/item/diamond.png")!
        ]

        for url in invalid {
            #expect(!ImagePolicy.isAllowed(url))
        }
    }
}
