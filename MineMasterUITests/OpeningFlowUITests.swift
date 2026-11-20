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
