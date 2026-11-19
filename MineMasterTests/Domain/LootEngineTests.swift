import Testing
@testable import MineMaster

@MainActor
@Suite("Moteur de butin")
struct LootEngineTests {
    @Test("Chaque booster retourne cinq cartes uniques")
    func fiveUniqueCards() {
        let catalog = Fixtures.mixedItems()
        let engine = LootEngine()

        for booster in Booster.allCases {
            var generator = SeededGenerator(seed: 42)
            let result = engine.draw(from: catalog, booster: booster, using: &generator)

            #expect(result.count == 5)
            #expect(Set(result.map(\.id)).count == result.count)
        }
    }

    @Test("La garantie de rareté est toujours satisfaite")
    func guaranteeIsSatisfied() {
        let catalog = Fixtures.mixedItems()
        let engine = LootEngine()

        for booster in Booster.allCases {
            guard let guarantee = booster.guarantee else {
                Issue.record("Booster sans garantie: \(booster)")
                continue
            }
            var generator = SeededGenerator(seed: 7)
            let result = engine.draw(from: catalog, booster: booster, using: &generator)

            #expect(result.contains { $0.rarity >= guarantee })
        }
    }

    @Test("Une rareté de multiplicateur zéro n'apparaît jamais")
    func zeroWeightRarityIsExcluded() {
        let catalog = Fixtures.mixedItems()
        var generator = SeededGenerator(seed: 99)

        let result = LootEngine().draw(from: catalog, booster: .common, using: &generator)

        #expect(!result.contains { $0.rarity == .epic || $0.rarity == .legendary })
    }

    @Test("Un catalogue vide retourne un tirage vide")
    func emptyCatalogReturnsEmptyDraw() {
        var generator = SeededGenerator()
        let result = LootEngine().draw(from: [], booster: .common, using: &generator)

        #expect(result.isEmpty)
    }

    @Test("Un petit catalogue retourne tous les items sans doublon")
    func smallCatalogReturnsAvailableItems() {
        let catalog = Fixtures.items(3, rarity: .common)
        var generator = SeededGenerator()

        let result = LootEngine().draw(from: catalog, booster: .common, using: &generator)

        #expect(result.count == 3)
        #expect(Set(result.map(\.id)) == Set(catalog.map(\.id)))
    }

    @Test("Le même générateur produit le même tirage")
    func sameSeedProducesSameDraw() {
        let catalog = Fixtures.mixedItems()
        let engine = LootEngine()
        var firstGenerator = SeededGenerator(seed: 1234)
        var secondGenerator = SeededGenerator(seed: 1234)

        let first = engine.draw(from: catalog, booster: .rare, using: &firstGenerator)
        let second = engine.draw(from: catalog, booster: .rare, using: &secondGenerator)

        #expect(first.map(\.id) == second.map(\.id))
    }
}
