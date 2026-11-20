import XCTest

final class DebugHierarchyUITests: WatchUITestCase {
    @MainActor
    func testDumpProfile() {
        let app = launchApp()
        let link = app.buttons["watch-profile-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()
        app.swipeUp()
        print("=====PROFILE=====")
        print(app.debugDescription)
    }
}
