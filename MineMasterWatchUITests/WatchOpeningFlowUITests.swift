import XCTest

/// Parcours d'ouverture sur Apple Watch.
final class WatchOpeningFlowUITests: WatchUITestCase {
    @MainActor
    func testOuvertureReveleLaPremiereCarte() {
        let app = launchApp()

        openPack(in: app)

        let card = app.buttons["watch-card-0"]
        card.tap()

        let count = app.staticTexts["watch-reveal-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 / 5 révélées")
    }

    @MainActor
    func testToucheUneCarteReveleePasseALaSuivante() {
        let app = launchApp()

        openPack(in: app)
        let firstCard = app.buttons["watch-card-0"]
        firstCard.tap()

        let count = app.staticTexts["watch-reveal-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 / 5 révélées")

        firstCard.tap()

        let cardIndex = app.staticTexts["watch-card-index"]
        XCTAssertTrue(cardIndex.waitForExistence(timeout: 5))
        XCTAssertEqual(cardIndex.label, "2 / 5")
    }

    @MainActor
    func testFermetureDUneSessionRevientALAccueil() {
        let app = launchApp()

        openPack(in: app)
        app.buttons["watch-close"].tap()

        XCTAssertTrue(app.buttons["watch-open-pack"].waitForExistence(timeout: 5))
    }
}
