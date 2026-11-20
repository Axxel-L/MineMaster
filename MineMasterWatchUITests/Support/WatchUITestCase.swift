import XCTest

/// Base commune des tests d'interface watchOS.
class WatchUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Lance l'application watchOS dans un état déterministe.
    ///
    /// - Parameters:
    ///   - hasSeenTutorial: Indique si le tutoriel de premier lancement doit être ignoré.
    ///   - extraArguments: Arguments de lancement complémentaires.
    /// - Returns: L'application prête à être interrogée.
    @MainActor
    func launchApp(hasSeenTutorial: Bool = true, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-hasSeenTutorial",
            hasSeenTutorial ? "YES" : "NO"
        ] + extraArguments
        app.launch()
        return app
    }

    /// Ouvre un pack jusqu'à la première carte.
    ///
    /// - Parameter app: Application en cours d'exécution.
    @MainActor
    func openPack(in app: XCUIApplication) {
        let open = app.buttons["watch-open-pack"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()

        let tear = app.buttons["watch-pack-tear"]
        XCTAssertTrue(tear.waitForExistence(timeout: 5))
        tear.tap()

        XCTAssertTrue(app.buttons["watch-card-0"].waitForExistence(timeout: 5))
    }
}
