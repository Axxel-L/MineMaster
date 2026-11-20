import XCTest

/// Parcours du profil et du tutoriel.
final class ProfileUITests: UITestCase {
    @MainActor
    func testRenaissanceVideLaCollectionEtLaPoussiere() {
        let app = launchApp(extraArguments: ["-uiTestingRebirthReady"])

        app.tabBars.buttons["Profil"].tap()

        let rebirth = app.buttons["rebirth"]
        XCTAssertTrue(rebirth.waitForExistence(timeout: 10))
        scrollToHittable(rebirth, in: app)
        rebirth.tap()

        let confirm = app.buttons["confirm-rebirth"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Niveau 1"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.staticTexts["0/6"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Boosters"].tap()
        let dust = app.descendants(matching: .any).matching(identifier: "dust-pill").firstMatch
        waitForLabel(dust, "0 poussière")
    }

    @MainActor
    func testTutorielDUnePremiereOuvertureSePasse() {
        let app = launchApp(hasSeenTutorial: false)

        XCTAssertTrue(app.staticTexts["Comment ça marche"].waitForExistence(timeout: 10))
        app.buttons["Passer"].tap()

        XCTAssertTrue(app.tabBars.buttons["Boosters"].waitForExistence(timeout: 5))
    }
}
