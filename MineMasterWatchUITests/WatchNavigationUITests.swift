import XCTest

/// Navigation, collection et profil sur Apple Watch.
final class WatchNavigationUITests: WatchUITestCase {
    @MainActor
    func testCollectionAfficheLeCatalogueDeTest() {
        let app = launchApp()

        let link = app.buttons["watch-collection-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()

        XCTAssertTrue(app.buttons["watch-item-diamond"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["watch-item-apple"].exists)
    }

    @MainActor
    func testProfilExposeLaProgressionEtLaRenaissance() {
        let app = launchApp()

        let link = app.buttons["watch-profile-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()

        XCTAssertTrue(app.staticTexts["watch-explorer-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["watch-rebirth-level"].exists)
    }

    @MainActor
    func testMarcheAfficheLesOffresEtLesModes() {
        let app = launchApp()

        let market = app.buttons["watch-market-link"]
        XCTAssertTrue(market.waitForExistence(timeout: 15))
        market.tap()

        XCTAssertTrue(app.buttons["watch-market-dirt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["watch-market-buy"].exists)
        XCTAssertTrue(app.buttons["watch-market-sell"].exists)
    }

    @MainActor
    func testTutorielSePasseALaPremiereOuverture() {
        let app = launchApp(hasSeenTutorial: false)

        XCTAssertTrue(app.staticTexts["Comment ça marche"].waitForExistence(timeout: 15))
        app.buttons["watch-skip-tutorial"].tap()

        XCTAssertTrue(app.buttons["watch-open-pack"].waitForExistence(timeout: 5))
    }
}
