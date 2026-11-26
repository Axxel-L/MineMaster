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
    func testFermetureDUneSessionRevientALAccueil() {
        let app = launchApp()

        openPack(in: app)
        app.buttons["watch-close"].tap()

        XCTAssertTrue(app.buttons["watch-open-pack"].waitForExistence(timeout: 5))
    }
}
