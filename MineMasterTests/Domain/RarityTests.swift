import Testing
@testable import MineMaster

@MainActor
@Suite("Valeurs de poussière par rareté")
struct RarityTests {
    @Test("Le barème de poussière d'un doublon est figé", arguments: [
        (Rarity.common, 2), (.uncommon, 4), (.rare, 8), (.epic, 20), (.legendary, 50)
    ])
    func baremeDoublon(rarity: Rarity, expected: Int) {
        #expect(rarity.dustValue == expected)
    }
}
