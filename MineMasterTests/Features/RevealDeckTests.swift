import Testing
@testable import MineMaster

@Suite("Révélation des cartes")
@MainActor
struct RevealDeckTests {
    @Test("Toucher une carte révélée passe à la suivante")
    func toucheUneCarteReveleeAvance() {
        let deck = RevealDeck(count: 5)

        deck.reveal(0)
        deck.advance(from: 0)

        #expect(deck.index == 1)
        #expect(deck.isCurrentRevealed == false)
    }

    @Test("Le passage ignore les cartes déjà révélées")
    func passageIgnoreLesCartesRevelees() {
        let deck = RevealDeck(count: 5)

        deck.reveal(0)
        deck.reveal(2)
        deck.advance(from: 0)

        #expect(deck.index == 1)

        deck.advance(from: 1)

        #expect(deck.index == 3)
    }

    @Test("Le passage revient à la première carte non révélée")
    func passageRevientALaPremiereCarteLibre() {
        let deck = RevealDeck(count: 5)

        for position in 1..<5 {
            deck.reveal(position)
        }
        deck.advance(from: 4)

        #expect(deck.index == 0)
    }

    @Test("Un paquet entièrement révélé ne change plus de carte")
    func paquetReveleNeChangePlus() {
        let deck = RevealDeck(count: 5)

        for position in 0..<5 {
            deck.reveal(position)
        }
        deck.advance(from: 2)

        #expect(deck.allRevealed)
        #expect(deck.index == 0)
    }

    @Test("La sélection ignore une position hors paquet")
    func selectionHorsPaquetIgnoree() {
        let deck = RevealDeck(count: 5)

        deck.select(9)

        #expect(deck.index == 0)
    }
}
