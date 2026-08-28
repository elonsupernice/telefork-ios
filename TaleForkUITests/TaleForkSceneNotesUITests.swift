import Foundation
import XCTest

@MainActor
final class TaleForkSceneNotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSceneMarkCanBeSavedAndResumedWithOfflineCatalog() throws {
        var app = configuredApp(screen: "playback-check", resetLocalState: true)
        app.launch()

        let markButton = app.buttons["scene-mark-player-action"]
        XCTAssertTrue(markButton.waitForExistence(timeout: 8))
        markButton.tap()

        let noteField = app.descendants(matching: .any)["scene-mark-note-field"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<3 where !noteField.exists {
            form.swipeUp()
        }
        XCTAssertTrue(noteField.waitForExistence(timeout: 3))
        noteField.tap()
        noteField.typeText("Doorway light changes")
        app.buttons["scene-mark-save"].tap()
        XCTAssertTrue(markButton.waitForExistence(timeout: 3))
        keepScreenshot(app, name: "01-player-after-scene-note-save")

        app.terminate()
        app = configuredApp(screen: "scene-notes", resetLocalState: false)
        app.launch()

        XCTAssertTrue(app.navigationBars["Scene Notes"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Doorway light changes"].waitForExistence(timeout: 8))
        let resumeButton = app.buttons["scene-mark-resume"]
        XCTAssertTrue(resumeButton.exists)
        XCTAssertTrue(resumeButton.isEnabled)
        Thread.sleep(forTimeInterval: 0.5)
        keepScreenshot(app, name: "02-scene-note-list")

        resumeButton.tap()
        XCTAssertTrue(app.buttons["scene-mark-player-action"].waitForExistence(timeout: 5))
    }

    func testIndependentTopLevelNavigationIsReachableWithOfflineCatalog() {
        let app = configuredApp(screen: "showcase", resetLocalState: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["The Lantern Room"].waitForExistence(timeout: 8))

        app.tabBars.buttons["Scene Notes"].tap()
        XCTAssertTrue(app.staticTexts["No scene notes yet"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.navigationBars["Studio"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["OFFLINE-PREVIEW"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        keepScreenshot(app, name: "03-independent-top-level-navigation")
    }

    func testSingleEpisodeStoryIsHiddenFromShowcase() {
        let app = configuredApp(screen: "showcase", resetLocalState: true)
        app.launch()

        XCTAssertTrue(app.buttons["The Lantern Room"].firstMatch.waitForExistence(timeout: 8))
        let singleEpisodeStory = app.buttons["Single Scene Preview"].firstMatch
        for _ in 0..<6 {
            XCTAssertFalse(singleEpisodeStory.exists)
            app.swipeUp()
        }
    }

    func testShowcaseAndDetailControlsStayInsideWindowBounds() {
        let app = configuredApp(screen: "showcase", resetLocalState: true)
        app.launch()

        let featuredStory = app.buttons["The Lantern Room"].firstMatch
        XCTAssertTrue(featuredStory.waitForExistence(timeout: 8))
        assertInsideWindow(featuredStory, app: app)
        featuredStory.tap()

        let startButton = app.buttons["Start Episode 1"]
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        assertInsideWindow(startButton, app: app)
        assertInsideWindow(saveButton, app: app)
        keepScreenshot(app, name: "04-showcase-detail-width-adaptation")
    }

    func testEpisodeElevenIsLockedAndOpensVIPPaywall() {
        let app = configuredApp(screen: "showcase", resetLocalState: true)
        app.launch()

        let featuredStory = app.buttons["The Lantern Room"].firstMatch
        XCTAssertTrue(featuredStory.waitForExistence(timeout: 8))
        featuredStory.tap()

        let episode10 = app.buttons["episode-10-button"]
        let episode11 = app.buttons["episode-11-button"]
        for _ in 0..<10 where !episode11.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(episode10.exists)
        XCTAssertTrue(episode11.waitForExistence(timeout: 3))
        XCTAssertTrue(episode11.isHittable)
        XCTAssertNotEqual(episode10.value as? String, "VIP")
        XCTAssertEqual(episode11.value as? String, "VIP")
        keepScreenshot(app, name: "05-episode-11-vip-lock")

        episode10.tap()
        XCTAssertTrue(app.buttons["scene-mark-player-action"].waitForExistence(timeout: 5))
        app.buttons["player-back-action"].tap()
        XCTAssertTrue(episode11.waitForExistence(timeout: 5))

        episode11.tap()
        XCTAssertTrue(app.navigationBars["VIP Membership"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "06-vip-weekly-paywall")
    }

    private func configuredApp(screen: String, resetLocalState: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = screen
        if resetLocalState {
            app.launchEnvironment["TALEFORK_RESET_LOCAL_STATE"] = "1"
        }
        return app
    }

    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertInsideWindow(_ element: XCUIElement, app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let windowFrame = app.windows.firstMatch.frame
        let elementFrame = element.frame
        XCTAssertGreaterThanOrEqual(elementFrame.minX, windowFrame.minX, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxX, windowFrame.maxX, file: file, line: line)
    }
}
