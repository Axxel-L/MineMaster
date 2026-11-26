import XCTest

/// Parcours de la collection.
final class CollectionUITests: UITestCase {
    @MainActor
    func testRechercheIsoleUnItemEtOuvreSonDetail() {
        let app = launchApp()
        openPack(in: app)
        revealAll(in: app)
        finishOpening(in: app)

        app.tabBars.buttons["Collection"].tap()

        let search = app.textFields["search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Diamond")

        let diamond = app.buttons["item-diamond"]
        XCTAssertTrue(diamond.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["item-dirt"].exists)

        diamond.tap()
        XCTAssertTrue(app.navigationBars["Diamond"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFiltrePossedesMasqueLesItemsJamaisObtenus() {
        let app = launchApp()
        openPack(in: app)
        revealAll(in: app)
        finishOpening(in: app)

        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.buttons["item-apple"].waitForExistence(timeout: 5))

        app.buttons["POSSÉDÉS"].tap()

        XCTAssertTrue(app.buttons["item-diamond"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["item-apple"].exists)
    }
}
