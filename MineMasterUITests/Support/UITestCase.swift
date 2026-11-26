import XCTest

/// Base commune des tests d'interface.
///
/// Chaque lancement active `-uiTesting`, qui remplace le catalogue distant par
/// six items fixes et coupe la synchronisation réseau.
class UITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Lance l'application avec un état déterministe.
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

    /// Ouvre un pack depuis l'accueil et attend la première carte.
    ///
    /// - Parameter app: Application en cours d'exécution.
        @MainActor
    func openPack(in app: XCUIApplication) {
        let open = app.buttons["open-pack"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()

        let tear = app.buttons["Ouvrir le pack"]
        XCTAssertTrue(tear.waitForExistence(timeout: 5))
        tear.tap()

        XCTAssertTrue(app.buttons["card-0"].waitForExistence(timeout: 5))
    }

    /// Révèle les cinq cartes du pack courant.
    ///
    /// Chaque carte se révèle au premier appui, puis un second appui fait
    /// glisser la révélation vers la carte suivante.
    ///
    /// - Parameter app: Application en cours d'exécution.
        @MainActor
    func revealAll(in app: XCUIApplication) {
        for position in 0..<5 {
            let card = app.buttons["card-\(position)"]
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            waitUntilHittable(card)
            card.tap()
            XCTAssertTrue(
                app.staticTexts["Révélées : \(position + 1) sur 5"].waitForExistence(timeout: 5)
            )
            if position < 4 {
                card.tap()
                let cardIndex = app.staticTexts["card-index"]
                XCTAssertTrue(cardIndex.waitForExistence(timeout: 5))
                waitForLabel(cardIndex, "Carte \(position + 2) sur 5")
            }
        }
        XCTAssertTrue(app.staticTexts["Révélées : 5 sur 5"].waitForExistence(timeout: 5))
    }

    /// Termine la session de révélation.
    ///
    /// - Parameter app: Application en cours d'exécution.
        @MainActor
    func finishOpening(in app: XCUIApplication) {
        let done = app.buttons["Terminer"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }

    /// Fait défiler l'écran jusqu'à rendre l'élément touchable.
    ///
    /// - Parameters:
    ///   - element: Élément à atteindre.
    ///   - app: Application en cours d'exécution.
        @MainActor
    func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable)
    }

    /// Attend qu'un libellé d'accessibilité prenne une valeur exacte.
    ///
    /// - Parameters:
    ///   - element: Élément observé.
    ///   - label: Libellé attendu.
    ///   - timeout: Délai maximal en secondes.
        @MainActor
    func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }
}
