import Foundation

/// Rendus 3D des créatures, hébergés par Minecraft Wiki.
///
/// Les URLs sont figées dans le binaire : aucune recherche dynamique n'est faite
/// au démarrage. Une texture d'entité reste utilisée en repli si le rendu échoue.
enum MobRenderAPI {
    private static let renders: [String: String] = [
        "zombie": "https://minecraft.wiki/images/Zombie_JE5_BE2.png",
        "skeleton": "https://minecraft.wiki/images/Lefthandedskeleton.png",
        "creeper": "https://minecraft.wiki/images/Creeper_JE3_BE1.png",
        "spider": "https://minecraft.wiki/images/Spider_JE5_BE4.png",
        "enderman": "https://minecraft.wiki/images/Enderman_JE3.png",
        "witch": "https://minecraft.wiki/images/Witch_JE4.png",
        "villager": "https://minecraft.wiki/images/Plains_Villager_Base_JE2.png",
        "wandering_trader": "https://minecraft.wiki/images/Wandering_Trader_JE1_BE1.png",
        "blaze": "https://minecraft.wiki/images/Blaze_JE2.gif",
        "ghast": "https://minecraft.wiki/images/Ghast_JE3_BE3.gif",
        "warden": "https://minecraft.wiki/images/Warden.gif",
        "allay": "https://minecraft.wiki/images/Allay_JE2_BE2.gif",
        "axolotl": "https://minecraft.wiki/images/Axolotl_Idle_Floor_Underwater.gif",
        "bee": "https://minecraft.wiki/images/Bee_JE1.gif",
        "frog": "https://minecraft.wiki/images/Temperate_Frog_JE1_BE1.gif",
        "goat": "https://minecraft.wiki/images/Goat_%28two_horns%29_JE1_BE1.png",
        "hoglin": "https://minecraft.wiki/images/Hoglin_JE3.png",
        "piglin": "https://minecraft.wiki/images/Piglin_JE1.png",
        "piglin_brute": "https://minecraft.wiki/images/Piglin_Brute_JE1.png",
        "strider": "https://minecraft.wiki/images/Strider_JE2_BE2.gif",
        "zoglin": "https://minecraft.wiki/images/Zoglin_JE1.png",
        "phantom": "https://minecraft.wiki/images/Phantom_JE2.gif",
        "shulker": "https://minecraft.wiki/images/Shulker_JE1_BE1.png",
        "magma_cube": "https://minecraft.wiki/images/Magma_Cube_JE2_BE2.png",
        "slime": "https://minecraft.wiki/images/Slime_JE3_BE2.png",
        "guardian": "https://minecraft.wiki/images/Guardian_JE2_BE2.gif",
        "elder_guardian": "https://minecraft.wiki/images/Elder_Guardian_JE2_BE2.gif",
        "drowned": "https://minecraft.wiki/images/Drowned_JE2.png",
        "husk": "https://minecraft.wiki/images/Husk_JE4_BE2.png",
        "stray": "https://minecraft.wiki/images/Stray_JE2_BE4.png",
        "bogged": "https://minecraft.wiki/images/Bogged_JE2_BE2.png",
        "pillager": "https://minecraft.wiki/images/Pillager_JE3.png",
        "vindicator": "https://minecraft.wiki/images/Vindicator_attacking.png",
        "evoker": "https://minecraft.wiki/images/Evoker_Summoning_Vexes.png",
        "ravager": "https://minecraft.wiki/images/Ravager_JE1.png",
        "vex": "https://minecraft.wiki/images/Vex_JE4.gif",
        "breeze": "https://minecraft.wiki/images/Breeze_BE1_JE2.webp",
        "creaking": "https://minecraft.wiki/images/Creaking_JE1_BE1.png",
        "armadillo": "https://minecraft.wiki/images/Armadillo_JE2_BE2.png",
        "sniffer": "https://minecraft.wiki/images/Sniffer_sniffsniff.gif",
        "camel": "https://minecraft.wiki/images/Camel_Idle.gif",
        "turtle": "https://minecraft.wiki/images/Turtle_JE3_BE1.png",
        "panda": "https://minecraft.wiki/images/Panda_JE1_BE1.png",
        "polar_bear": "https://minecraft.wiki/images/Polar_Bear_JE2_BE2.png",
        "fox": "https://minecraft.wiki/images/Fox_JE1_BE1.png",
        "ocelot": "https://minecraft.wiki/images/Ocelot_JE2_BE2.png",
        "cat": "https://minecraft.wiki/images/Jellie_Cat.png",
        "wolf": "https://minecraft.wiki/images/Wolf_JE2_BE2.png",
        "horse": "https://minecraft.wiki/images/White_Horse.png",
        "donkey": "https://minecraft.wiki/images/Donkey_JE5.png",
        "llama": "https://minecraft.wiki/images/White_Llama_JE2_BE2.png",
        "bat": "https://minecraft.wiki/images/Bat_JE4_BE3.gif",
        "chicken": "https://minecraft.wiki/images/Chicken_JE2_BE2.png",
        "cow": "https://minecraft.wiki/images/Cow_JE7_BE4.png",
        "mooshroom": "https://minecraft.wiki/images/Red_Mooshroom_JE5_BE3.png",
        "pig": "https://minecraft.wiki/images/Temperate_Pig_JE4_BE2.png",
        "rabbit": "https://minecraft.wiki/images/Brown_Rabbit_BE4.png",
        "sheep": "https://minecraft.wiki/images/White_Sheep_JE5.png",
        "squid": "https://minecraft.wiki/images/Squid_JE2_BE2.gif",
        "glow_squid": "https://minecraft.wiki/images/Glow_Squid_JE1.gif",
        "dolphin": "https://minecraft.wiki/images/Dolphin.gif",
        "cod": "https://minecraft.wiki/images/Cod.gif",
        "salmon": "https://minecraft.wiki/images/Salmon.gif",
        "pufferfish": "https://minecraft.wiki/images/Pufferfish_small.gif",
        "tropical_fish": "https://minecraft.wiki/images/Clownfish.png",
        "parrot": "https://minecraft.wiki/images/Red_Parrot_JE1_BE1.png"
    ]

    /// Retourne le rendu d'une créature.
    ///
    /// - Parameter id: Identifiant du catalogue.
    /// - Returns: L'URL du rendu, ou `nil` pour les items non-créatures.
    static func url(for id: String) -> URL? {
        renders[id].flatMap(URL.init(string:))
    }
}
