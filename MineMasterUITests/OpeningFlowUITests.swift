import XCTest

/// Parcours d'ouverture d'un pack.
final class OpeningFlowUITests: UITestCase {
    @MainActor
    func testOuvertureReveleCinqCartesEtRevientALAccueil() {
        let app = launchApp()

        openPack(in: app)
        revealAll(in: app)

        XCTAssertTrue(app.buttons["Terminer"].exists)
        finishOpening(in: app)
        XCTAssertTrue(app.buttons["open-pack"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testToucheUneCarteReveleePasseALaSuivante() {
        let app = launchApp()

        openPack(in: app)
        let firstCard = app.buttons["card-0"]
        firstCard.tap()

        XCTAssertTrue(app.staticTexts["Révélées : 1 sur 5"].waitForExistence(timeout: 5))
        firstCard.tap()

        let cardIndex = app.staticTexts["card-index"]
        XCTAssertTrue(cardIndex.waitForExistence(timeout: 5))
        waitForLabel(cardIndex, "Carte 2 sur 5")
    }

    @MainActor
    func testDeuxiemeOuvertureCrediteLaPoussiereDesDoublons() {
        let app = launchApp()
        let dust = app.descendants(matching: .any).matching(identifier: "dust-pill").firstMatch
        XCTAssertTrue(dust.waitForExistence(timeout: 10))
        waitForLabel(dust, "0 poussière")

        openPack(in: app)
        revealAll(in: app)
        finishOpening(in: app)
        waitForLabel(dust, "0 poussière")

        openPack(in: app)
        revealAll(in: app)
        finishOpening(in: app)
        waitForLabel(dust, "66 poussière")
    }
}
