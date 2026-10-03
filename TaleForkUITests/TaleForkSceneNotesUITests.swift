import Foundation
import XCTest

@MainActor
final class TaleForkSceneNotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Explicit live acceptance for an already-installed account. No local
    /// reset, checkout, refund, restore purchase or account deletion is used.
    func testLiveAccountAndCatalogSurviveRelaunch() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_SERVICE_BASE_URL"] = "https://app.duanjufafafa.fun/"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        defer { app.terminate() }

        let preferences = app.tabBars.buttons["偏好"]
        XCTAssertTrue(preferences.waitForExistence(timeout: 10), "Keep the existing onboarding/account state")
        let drama = app.buttons.matching(NSPredicate(format: "value MATCHES %@", "^[0-9]+ 集$")).firstMatch
        XCTAssertTrue(drama.waitForExistence(timeout: 35), "The live catalog must contain real multi-episode dramas")
        XCTAssertFalse(app.staticTexts["劇場連接失敗"].exists)
        keepScreenshot(app, name: "keychain-repaired-live-catalog")

        preferences.tap()
        let loadedID = NSPredicate(format: "value MATCHES %@", "^[0-9]{9}$")
        let userID = app.staticTexts.matching(loadedID).firstMatch
        XCTAssertTrue(userID.waitForExistence(timeout: 15))
        let originalID = try XCTUnwrap(userID.value as? String)
        keepScreenshot(app, name: "keychain-repaired-existing-user-id")

        app.terminate()
        app.launch()
        XCTAssertTrue(preferences.waitForExistence(timeout: 10))
        preferences.tap()
        let unchangedID = NSPredicate(format: "value == %@", originalID)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: unchangedID, evaluatedWith: userID)], timeout: 20), .completed)
        keepScreenshot(app, name: "keychain-repaired-user-id-after-relaunch")
    }

    func testHostedPageShowsLoadingUntilReady() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "hosted-result-check"
        app.launchEnvironment["TALEFORK_UI_HOSTED_WAIT_FOR_READY"] = "1"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        defer { app.terminate() }

        let loading = app.staticTexts["hosted-page-loading"]
        XCTAssertTrue(loading.waitForExistence(timeout: 10))
        XCTAssertEqual(loading.label, "載入中…")
        XCTAssertTrue(app.buttons["hosted-page-close"].isHittable)
        keepScreenshot(app, name: "hosted-page-loading-traditional")

        let ready = app.webViews.buttons["完成測試載入"]
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        ready.tap()
        XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hosted-page-close"].isHittable)
        keepScreenshot(app, name: "hosted-page-ready-loading-hidden")
    }

    func testHostedSuccessOnlyShowsCornerCloseAfterReady() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "hosted-result-check"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["付款成功"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.webViews.buttons["關閉並返回 APP"].exists)
        let close = app.buttons["hosted-page-close"]
        XCTAssertTrue(close.isHittable, "Native escape must remain after the page sends ready")
        keepScreenshot(app, name: "result-corner-close-only")
        close.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.webViews.firstMatch.exists)
        app.terminate()
    }

    /// Both route changes use the production manifest/network/offer decoding
    /// path against a loopback fixture, without changing the real backend.
    func testServerModeOffOnOffRefreshesWithoutRestart() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launch()
        XCTAssertTrue(app.buttons["hosted-offer-2019"].waitForExistence(timeout: 30))
        for id in ["2019", "2020", "2021"] { XCTAssertTrue(app.buttons["hosted-offer-\(id)"].isHittable) }
        XCTAssertFalse(app.buttons["apple-membership-purchase"].exists)
        XCTAssertTrue(app.buttons["hosted-offer-2019"].label.contains("原價 788"))
        XCTAssertFalse(app.buttons["hosted-offer-2019"].label.contains("not-for-display"))
        keepScreenshot(app, name: "routing-mode-off-three-hosted-plans")
        app.buttons["membership-purchase-details"].tap()
        XCTAssertTrue(app.staticTexts["membership-purchase-details-content"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["membership-purchase-details-content"].label.contains("體驗及續訂須知"))
        app.navigationBars.buttons.firstMatch.tap()

        XCUIDevice.shared.press(.home)
        try await configureRoutingFixture(review: true)
        app.activate()
        XCTAssertTrue(app.buttons["apple-offer-com.talefork.storypaths.vip.weekly"].waitForExistence(timeout: 35))
        XCTAssertFalse(app.buttons["hosted-membership-open"].exists)
        keepScreenshot(app, name: "routing-mode-on-apple-plans")

        XCUIDevice.shared.press(.home)
        try await configureRoutingFixture(review: false)
        app.activate()
        XCTAssertTrue(app.buttons["hosted-offer-2019"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["apple-membership-purchase"].exists)
        keepScreenshot(app, name: "routing-mode-off-again-no-stale-apple-cache")
        try await assertFixtureNeverOrdered()
        app.terminate()
    }

    /// Explicitly selected for the user's current backend-off acceptance
    /// check. Reads configuration/offers only; never taps the checkout action.
    func testCurrentBackendDisplaysThreeHostedPlansWithoutOrdering() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "0"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        let next = app.buttons["onboarding-next"]
        if next.waitForExistence(timeout: 3) {
            for _ in 0..<4 where next.exists { next.tap() }
            app.buttons["onboarding-begin"].tap()
        } else {
            let preferences = app.tabBars.buttons["偏好"]
            XCTAssertTrue(preferences.waitForExistence(timeout: 10))
            preferences.tap()
            let open = app.buttons["profile-membership-open"]
            XCTAssertTrue(open.waitForExistence(timeout: 10))
            open.tap()
        }
        let first = app.buttons["hosted-offer-2019"]
        guard first.waitForExistence(timeout: 30) else {
            keepScreenshot(app, name: "routing-current-backend-load-failure")
            XCTFail("Current backend offers were not displayed: \(app.staticTexts["membership-load-error"].label)")
            app.terminate()
            return
        }
        for (id, price) in [("2019", "HK$1.00"), ("2020", "HK$5.90"), ("2021", "HK$29.90")] {
            let card = app.buttons["hosted-offer-\(id)"]
            XCTAssertTrue(card.isHittable)
            XCTAssertTrue(card.label.contains(price), "Prices must be returned by the real backend")
        }
        XCTAssertFalse(app.buttons["apple-membership-purchase"].exists)
        XCTAssertTrue(app.buttons["hosted-membership-open"].isHittable)
        XCTAssertTrue(app.buttons["membership-purchase-details"].isHittable)
        keepScreenshot(app, name: "routing-current-backend-real-three-plans")
        app.buttons["hosted-offer-2020"].tap()
        XCTAssertTrue(app.buttons["hosted-offer-2020"].isSelected)
        app.buttons["hosted-offer-2019"].tap()
        keepScreenshot(app, name: "routing-current-backend-plan-selection-working")
        app.terminate()
    }

    func testServerLoadingTimeoutOffersRetryAndRecovers() async throws {
        try await configureRoutingFixture(review: false, delay: 24)
        let app = routingFixtureApp()
        app.launch()
        XCTAssertTrue(app.buttons["membership-load-retry"].waitForExistence(timeout: 28))
        XCTAssertTrue(app.staticTexts["membership-load-error"].label.contains("逾時"))
        XCTAssertFalse(app.buttons["apple-membership-purchase"].exists)
        keepScreenshot(app, name: "routing-timeout-visible-retry")
        try await configureRoutingFixture(review: false)
        app.buttons["membership-load-retry"].tap()
        XCTAssertTrue(app.buttons["hosted-offer-2019"].waitForExistence(timeout: 12))
        keepScreenshot(app, name: "routing-timeout-recovered-server-plans")
        try await assertFixtureNeverOrdered()
        app.terminate()
    }

    private func routingFixtureApp() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "0"
        app.launchEnvironment["TALEFORK_SERVICE_BASE_URL"] = "http://127.0.0.1:18642/"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        return app
    }

    private func configureRoutingFixture(review: Bool, delay: Int = 0) async throws {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:18642/fixture")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.httpBody = try JSONSerialization.data(withJSONObject: ["review": review, "delay": delay, "fail": false])
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    private func assertFixtureNeverOrdered() async throws {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["checkoutRequests"] as? Int, 0, "Viewing or switching plans must never create an order")
    }

    /// Real StoreKit products exercise the production Product rendering path.
    /// No purchase, credentials, or App Store Connect setting is changed.
    func testGoldAppleThreePortraitPlansAndRetention() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let weekly = app.buttons["apple-offer-com.talefork.storypaths.vip.weekly"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 75))
        let monthly = app.buttons["apple-offer-com.talefork.storypaths.vip.monthly"]
        let quarterly = app.buttons["apple-offer-com.talefork.storypaths.vip.quarterly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 75))
        XCTAssertTrue(quarterly.waitForExistence(timeout: 75))
        XCTAssertTrue(monthly.label.contains("每月會員"))
        XCTAssertTrue(quarterly.label.contains("季度會員"))
        XCTAssertLessThan(weekly.frame.midX, monthly.frame.midX)
        XCTAssertLessThan(monthly.frame.midX, quarterly.frame.midX)
        XCTAssertEqual(weekly.frame.minY, monthly.frame.minY, accuracy: 1)
        XCTAssertEqual(monthly.frame.minY, quarterly.frame.minY, accuracy: 1)
        XCTAssertTrue(weekly.label.contains("每週會員"))
        XCTAssertGreaterThanOrEqual(weekly.frame.height, 148)
        XCTAssertLessThan(weekly.frame.width, weekly.frame.height)
        XCTAssertFalse(app.buttons["external-membership-checkout"].exists)
        let restore = app.buttons["apple-membership-restore"]
        let terms = app.buttons["使用條款"]
        let privacy = app.buttons["隱私"]
        for link in [restore, terms, privacy] {
            XCTAssertTrue(link.isHittable, "Compact Apple footer must be visible without scrolling")
            XCTAssertGreaterThanOrEqual(link.frame.height, 44)
        }
        XCTAssertLessThan(restore.frame.midX, terms.frame.midX)
        XCTAssertLessThan(terms.frame.midX, privacy.frame.midX)
        XCTAssertEqual(restore.frame.midY, terms.frame.midY, accuracy: 1)
        XCTAssertTrue(app.buttons["apple-membership-purchase"].isHittable)
        let action = app.buttons["apple-membership-purchase"]
        let renewal = app.staticTexts["apple-membership-renewal"]
        XCTAssertTrue(renewal.isHittable)
        XCTAssertGreaterThanOrEqual(renewal.frame.minY - action.frame.maxY, 7)
        XCTAssertLessThanOrEqual(renewal.frame.minY - action.frame.maxY, 9)
        XCTAssertEqual(restore.frame.minY, renewal.frame.maxY, accuracy: 1,
                       "Required renewal copy remains directly above the compact footer")
        assertCarouselIsFullyVisibleOnFirstScreen(app)
        keepScreenshot(app, name: "gold-apple-three-portrait-plans")
        XCTAssertTrue(weekly.isSelected)
        monthly.tap()
        XCTAssertTrue(monthly.isSelected)
        XCTAssertFalse(weekly.isSelected)
        XCTAssertTrue(renewal.label.contains("每月會員"))
        quarterly.tap()
        XCTAssertTrue(quarterly.isSelected)
        XCTAssertFalse(monthly.isSelected)
        XCTAssertTrue(renewal.label.contains("季度會員"))
        XCTAssertTrue(app.staticTexts["apple-membership-renewal"].exists)
        app.buttons["membership-close"].tap()
        XCTAssertTrue(app.buttons["membership-retention-continue"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "gold-apple-retention")
        app.terminate()
    }

    /// Live poster data with local StoreKit plans: do not substitute the
    /// artwork-free offline catalog or initiate a purchase for this check.
    func testGoldAppleLiveCarouselCanSwitchDramas() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let carousel = app.otherElements["membership-exclusive-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 45), "Real short dramas must load under the simulator's ad-hoc identity")
        assertCarouselIsFullyVisibleOnFirstScreen(app)
        let firstTitle = carousel.label
        XCTAssertFalse(firstTitle.isEmpty)
        let start = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let end = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        let changed = NSPredicate { _, _ in carousel.label != firstTitle }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: changed, evaluatedWith: carousel)], timeout: 5), .completed)
        for product in ["weekly", "monthly", "quarterly"] {
            XCTAssertTrue(app.buttons["apple-offer-com.talefork.storypaths.vip.\(product)"].waitForExistence(timeout: 30))
        }
        keepScreenshot(app, name: "gold-apple-live-carousel-after-swipe")
        app.terminate()
    }

    /// Isolate the gold CTA animation from media/network changes. Never purchase.
    func testMembershipOpenButtonBreathesWithoutMoving() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        let action = app.buttons["apple-membership-purchase"]
        XCTAssertTrue(action.waitForExistence(timeout: 75))
        keepScreenshot(app, name: "membership-breathing-before-ready")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "membership-breathing-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let ready = NSPredicate(format: "hittable == true")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: ready, evaluatedWith: action)], timeout: 15), .completed)
        let originalFrame = action.frame
        let frameOne = action.screenshot()
        Thread.sleep(forTimeInterval: 0.8)
        let frameTwo = action.screenshot()
        XCTAssertNotEqual(frameOne.pngRepresentation, frameTwo.pngRepresentation,
                          "The gold surface must brighten and dim")
        XCTAssertEqual(action.frame, originalFrame, "Breathing must not move or resize the button")
        for (index, frame) in [frameOne, frameTwo].enumerated() {
            let attachment = XCTAttachment(screenshot: frame)
            attachment.name = "membership-breathing-light-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        // Sample a complete light cycle so the left-to-right beam and the
        // whole-button breathing can both be inspected, without purchasing.
        for index in 0..<8 {
            let attachment = XCTAttachment(screenshot: action.screenshot())
            attachment.name = "membership-breathing-and-sheen-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertEqual(action.frame, originalFrame)
        keepScreenshot(app, name: "membership-breathing-paywall")
        app.buttons["membership-close"].tap()
        let retentionAction = app.buttons["membership-retention-continue"]
        XCTAssertTrue(retentionAction.waitForExistence(timeout: 5))
        XCTAssertTrue(retentionAction.isHittable)
        let retentionFrame = retentionAction.frame
        let retentionOne = retentionAction.screenshot()
        Thread.sleep(forTimeInterval: 0.8)
        let retentionTwo = retentionAction.screenshot()
        XCTAssertNotEqual(retentionOne.pngRepresentation, retentionTwo.pngRepresentation)
        XCTAssertEqual(retentionAction.frame, retentionFrame)
        keepScreenshot(app, name: "membership-breathing-retention")
        app.terminate()
    }

    /// Real HTTPS media and AVPlayer's clock, not an animated poster or mock.
    /// This never taps either purchase action or confirms account deletion.
    func testGoalMainVideoAutoplayTraditionalRetentionAndButtonMotion() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        let monthly = app.buttons["apple-offer-com.talefork.storypaths.vip.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 75))
        let mainVideo = app.descendants(matching: .any)["membership-paywall-video"].firstMatch
        assertVideoAdvances(mainVideo, minimum: 2, timeout: 45)
        let mainTime = playbackSeconds(mainVideo)
        XCTAssertFalse(app.buttons["membership-paywall-video-toggle"].exists,
                       "Membership previews must not show a play/pause control")
        mainVideo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertVideoAdvances(mainVideo, minimum: mainTime + 1, timeout: 10)
        let action = app.buttons["apple-membership-purchase"]
        XCTAssertTrue(action.isHittable)
        let frameOne = action.screenshot()
        Thread.sleep(forTimeInterval: 0.8)
        let frameTwo = action.screenshot()
        XCTAssertNotEqual(frameOne.pngRepresentation, frameTwo.pngRepresentation,
                          "The primary button's light must actually animate")
        for (index, frame) in [frameOne, frameTwo].enumerated() {
            let attachment = XCTAttachment(screenshot: frame)
            attachment.name = "goal-cta-motion-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        keepScreenshot(app, name: "goal-main-real-video-and-apple-plans")
        monthly.tap()
        app.buttons["membership-close"].tap()
        let title = app.staticTexts["membership-retention-plan-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "每月會員")
        XCTAssertFalse(app.staticTexts["TaleFork VIP Monthly"].exists)
        XCTAssertFalse(app.staticTexts["第 11 集之後的故事還在等你。你可以先留下，稍後再決定。"].exists)
        let retentionVideo = app.descendants(matching: .any)["membership-retention-video"].firstMatch
        assertVideoAdvances(retentionVideo, minimum: 10, timeout: 45)
        XCTAssertFalse(app.buttons["membership-retention-video-toggle"].exists,
                       "Retention previews must not show a play/pause control")
        let retentionTime = playbackSeconds(retentionVideo)
        retentionVideo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertVideoAdvances(retentionVideo, minimum: retentionTime + 1, timeout: 10)
        let evidence = XCTAttachment(string: "Main AVPlayer advanced from \(mainTime)s after tapping the preview; retention AVPlayer = \(retentionVideo.value ?? ""). Both play/pause controls absent. Real HTTPS media. No purchase initiated.")
        evidence.name = "goal-real-video-clock-evidence"
        evidence.lifetime = .keepAlways
        add(evidence)
        keepScreenshot(app, name: "goal-retention-traditional-monthly-real-video")
        app.terminate()
    }

    func testGoalProfileGoldCardAndSecondaryAccountSettings() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "studio"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        let card = app.otherElements["profile-membership-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        keepScreenshot(app, name: "goal-profile-card-before-verification")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "goal-profile-accessibility-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        for label in ["TaleFork VIP", "連續觀看", "完整劇集", "片單收藏", "個人場記"] {
            XCTAssertTrue(card.staticTexts[label].exists, "Own benefit must remain in the gold card: \(label)")
        }
        XCTAssertFalse(card.staticTexts["第 11 集起已鎖定"].exists,
                       "The profile VIP card must not display the episode-lock message")
        XCTAssertTrue(app.buttons["profile-membership-open"].isHittable)
        XCTAssertFalse(app.buttons["settings-delete-account"].exists)
        XCTAssertFalse(app.buttons["註銷帳戶並登出"].exists)
        keepScreenshot(app, name: "goal-profile-own-gold-vip-card")
        let settings = app.buttons["profile-settings"]
        reveal(settings, in: app.scrollViews.firstMatch)
        XCTAssertTrue(settings.isHittable)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44)
        keepScreenshot(app, name: "goal-profile-settings-last")
        settings.tap()
        let deletion = app.buttons["settings-delete-account"]
        XCTAssertTrue(deletion.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(deletion.frame.height, 44)
        XCTAssertTrue(app.navigationBars["設定"].exists)
        keepScreenshot(app, name: "goal-secondary-settings-delete-account")
        deletion.tap()
        let cancel = app.alerts.buttons["取消"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(deletion.exists, "Cancel must not delete the account")
        app.terminate()
    }

    private func playbackSeconds(_ video: XCUIElement) -> Double {
        guard let value = video.value as? String,
              let seconds = Double(value.split(separator: ":").last?.split(separator: ";").first ?? "") else { return -1 }
        return seconds
    }

    private func assertVideoAdvances(_ video: XCUIElement, minimum: Double, timeout: TimeInterval) {
        let advancing = NSPredicate { _, _ in
            (video.value as? String)?.hasPrefix("playing:") == true && self.playbackSeconds(video) >= minimum
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: advancing, evaluatedWith: video)], timeout: timeout), .completed,
                       "Actual AVPlayer clock/status must advance: \(video.value ?? "missing")")
    }

    func testGoldMembershipAccessibilityLayout() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let weekly = app.buttons["apple-offer-com.talefork.storypaths.vip.weekly"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 75))
        keepScreenshot(app, name: "gold-membership-accessibility-top")
        let dock = app.scrollViews["membership-plans-scroll"]
        let purchase = app.buttons["apple-membership-purchase"]
        reveal(purchase, in: dock)
        keepScreenshot(app, name: "gold-membership-accessibility-after-scroll")
        let layout = XCTAttachment(string: app.debugDescription)
        layout.name = "gold-membership-accessibility-hierarchy"
        layout.lifetime = .keepAlways
        add(layout)
        XCTAssertTrue(purchase.isHittable)
        keepScreenshot(app, name: "gold-membership-accessibility-action")
        let renewal = app.staticTexts["apple-membership-renewal"]
        reveal(renewal, in: dock)
        XCTAssertTrue(renewal.isHittable)
        let restore = app.buttons["apple-membership-restore"]
        reveal(restore, in: dock)
        XCTAssertTrue(restore.isHittable)
        for label in ["使用條款", "隱私"] {
            let link = app.buttons[label]
            reveal(link, in: dock)
            XCTAssertTrue(link.isHittable)
            XCTAssertGreaterThanOrEqual(link.frame.height, 44)
        }
        keepScreenshot(app, name: "gold-membership-accessibility-restore-and-legal")
        app.terminate()
    }

    /// Full-screen swipe inertia can skip a short dock's entire target. Use
    /// small drags wholly inside its visible viewport and stop at the control.
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
        for _ in 0..<14 where !element.isHittable {
            let below = element.frame.midY >= scroll.frame.midY
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.82 : 0.48))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.48 : 0.82))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
    }

    /// Assert before any vertical drag: the whole carousel must fit above the
    /// dock, not merely exist offscreen or become visible after scrolling.
    private func assertCarouselIsFullyVisibleOnFirstScreen(_ app: XCUIApplication) {
        let carousel = app.otherElements["membership-exclusive-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 10))
        let dock = app.scrollViews["membership-plans-scroll"]
        let navigation = app.navigationBars.firstMatch
        XCTAssertGreaterThanOrEqual(carousel.frame.height, 216)
        XCTAssertGreaterThanOrEqual(carousel.frame.minY, navigation.frame.maxY)
        XCTAssertLessThanOrEqual(carousel.frame.maxY, dock.frame.minY)
        XCTAssertTrue(carousel.isHittable)
        let benefits = app.otherElements["membership-benefits-card"]
        XCTAssertTrue(benefits.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(benefits.frame.minY, carousel.frame.maxY)
        XCTAssertLessThanOrEqual(benefits.frame.maxY, dock.frame.minY, "The plan dock must not cover membership benefits")
        for label in ["連續觀看", "片單收藏", "個人場記"] {
            let benefit = benefits.staticTexts[label]
            XCTAssertTrue(benefit.exists)
            XCTAssertTrue(benefit.isHittable)
            XCTAssertLessThanOrEqual(benefit.frame.maxY, dock.frame.minY)
        }
        XCTAssertFalse(benefits.staticTexts["解鎖第 11 集起的全部劇集"].exists)
    }

    /// Uses the isolated backend QA channel. It never starts either purchase flow.

    /// Opt-in live UI acceptance: opens an unpaid checkout only. Never enters
    /// wallet credentials, confirms a payment, or clears the existing visitor.

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
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "06-vip-weekly-paywall")

        app.buttons["membership-close"].tap()
        XCTAssertTrue(app.staticTexts["Your next episode is waiting"].waitForExistence(timeout: 3))
        app.buttons["membership-retention-close"].tap()
        XCTAssertTrue(app.navigationBars["VIP Membership"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(episode11.waitForExistence(timeout: 3))
        XCTAssertEqual(episode11.value as? String, "VIP", "Leaving checkout must not unlock paid episodes")
    }

    func testOnboardingOpensMembershipAndCloseShowsRetention() {
        let app = configuredApp(resetLocalState: true)
        app.launch()

        let nextButton = app.buttons["onboarding-next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        for _ in 0..<4 where nextButton.exists { nextButton.tap() }

        let beginButton = app.buttons["onboarding-begin"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 3))
        beginButton.tap()

        XCTAssertTrue(app.navigationBars["VIP Membership"].waitForExistence(timeout: 8))
        let closeButton = app.buttons["membership-close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        XCTAssertEqual(closeButton.label, "Back", "The membership exit control must be labelled Back")
        keepScreenshot(app, name: "08-membership-back-before-retention")
        app.swipeDown()
        XCTAssertTrue(closeButton.exists, "A downward swipe must not dismiss the full-screen paywall")
        closeButton.tap()

        XCTAssertTrue(app.staticTexts["Your next episode is waiting"].waitForExistence(timeout: 3))
        let continueButton = app.buttons["membership-retention-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertFalse(closeButton.exists, "Retention replaces the back arrow with its top-right X")
        XCTAssertTrue(app.buttons["membership-retention-close"].isHittable)
        app.swipeDown()
        XCTAssertTrue(continueButton.exists, "Retention must not be swipe-dismissed")
        continueButton.tap()
        XCTAssertTrue(app.staticTexts["Your next episode is waiting"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        closeButton.tap()
        XCTAssertTrue(app.staticTexts["Your next episode is waiting"].waitForExistence(timeout: 3))
        let leaveButton = app.buttons["membership-retention-close"]
        XCTAssertTrue(leaveButton.waitForExistence(timeout: 3))
        keepScreenshot(app, name: "07-membership-retention-after-onboarding")
        leaveButton.tap()
        XCTAssertTrue(app.navigationBars["VIP Membership"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["The Lantern Room"].firstMatch.waitForExistence(timeout: 3))
    }

    /// Bundled artwork renders with an offline catalog; completion opens the existing paywall without submitting payment.
    func testHongKongPosterOnboardingAndMembershipEntry() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TALEFORK_RESET_LOCAL_STATE"] = "1"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_ANALYTICS_DISABLED"] = "1"
        // Chinese onboarding uses Hong Kong Traditional copy even on a Hans device.
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        defer { app.terminate() }

        let count = app.staticTexts["onboarding-page-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 / 4")
        XCTAssertTrue(app.staticTexts["沉浸\n高清體驗"].exists)
        XCTAssertFalse(app.buttons["onboarding-skip"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["onboarding-real-video"].exists)
        let comparison = app.descendants(matching: .any)["onboarding-hd-comparison"].firstMatch
        XCTAssertTrue(comparison.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["HD 精品"].exists)
        XCTAssertFalse(app.staticTexts["畫質效果示意"].exists)
        for quality in ["540P", "720P", "1080P"] {
            XCTAssertTrue(app.descendants(matching: .any)["onboarding-quality-\(quality)"].firstMatch.exists)
            XCTAssertFalse(app.buttons["onboarding-quality-\(quality)"].exists)
        }
        XCTAssertTrue(app.buttons["onboarding-next"].isHittable)
        keepScreenshot(app, name: "hk-onboarding-1-static-hd-comparison")

        app.buttons["onboarding-next"].tap()
        XCTAssertEqual(count.label, "2 / 4")
        XCTAssertTrue(app.staticTexts["盡享\n追劇時光"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-story-artwork"].firstMatch.exists)
        XCTAssertFalse(app.buttons["onboarding-skip"].exists)
        XCTAssertFalse(app.staticTexts["TaleFork VIP"].exists)
        XCTAssertFalse(app.staticTexts["畫質效果示意"].exists)
        keepScreenshot(app, name: "hk-onboarding-2-adventure")

        app.buttons["onboarding-next"].tap()
        XCTAssertEqual(count.label, "3 / 4")
        XCTAssertTrue(app.staticTexts["沉浸式\n精品短劇"].exists)
        XCTAssertTrue(app.staticTexts["搭車途中、收工之後，揀套好劇，留返一刻畀自己。"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-ending-artwork"].firstMatch.exists)
        XCTAssertFalse(app.buttons["onboarding-skip"].exists)
        XCTAssertFalse(app.staticTexts["TaleFork VIP"].exists)
        XCTAssertFalse(app.staticTexts["查看會員方案"].exists)
        XCTAssertFalse(app.buttons["apple-membership-purchase"].exists)
        XCTAssertTrue(app.buttons["onboarding-next"].isHittable)
        XCTAssertFalse(app.buttons["onboarding-begin"].exists)
        keepScreenshot(app, name: "hk-onboarding-3-immersive-cinema")
        XCTAssertFalse(app.staticTexts["畫質效果示意"].exists)
        app.buttons["onboarding-next"].tap()
        XCTAssertEqual(count.label, "4 / 4")
        XCTAssertTrue(app.staticTexts["每日更新\n新劇不斷"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今日想睇邊套？新故事陸續登場，總有一套啱你心水。"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-finale-artwork"].firstMatch.exists)
        XCTAssertFalse(app.buttons["onboarding-skip"].exists)
        XCTAssertFalse(app.buttons["apple-membership-purchase"].exists)
        let begin = app.buttons["onboarding-begin"]
        XCTAssertTrue(begin.isHittable)
        XCTAssertEqual(begin.label, "開始追劇")
        XCTAssertFalse(app.staticTexts["畫質效果示意"].exists)
        keepScreenshot(app, name: "hk-onboarding-4-daily-poster-wall")
        begin.tap()
        XCTAssertTrue(app.buttons["membership-close"].waitForExistence(timeout: 35))
        keepScreenshot(app, name: "hk-onboarding-complete-existing-membership-page")
    }

    func testOnboardingLargeTypeAndCompletionRemainUsable() {
        let app = configuredApp(resetLocalState: true)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { app.terminate() }
        let pages: [(scroll: String, body: String)] = [
            ("onboarding-intro-scroll", "Every glance. Every spark. See the details and feel every scene."),
            ("onboarding-story-scroll", "Romance, suspense and unexpected twists. Follow a story from its first scene to the ending you want to see."),
            ("onboarding-ending-scroll", "On the way home or at the end of the day, find a drama and take a moment for yourself."),
            ("onboarding-finale-scroll", "What will you watch today? Discover a new story that draws you in.")
        ]
        for (index, page) in pages.enumerated() {
            let action = app.buttons[index == pages.count - 1 ? "onboarding-begin" : "onboarding-next"]
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            XCTAssertTrue(action.isHittable)
            XCTAssertEqual(app.staticTexts["onboarding-page-count"].label, "\(index + 1) / 4")
            XCTAssertFalse(app.buttons["onboarding-skip"].exists)
            XCTAssertFalse(app.staticTexts["TaleFork VIP"].exists)
            XCTAssertFalse(app.staticTexts["Illustrative image-quality comparison"].exists)
            keepScreenshot(app, name: "hk-onboarding-large-type-page-\(index + 1)")
            let scroll = app.scrollViews[page.scroll].firstMatch
            for _ in 0..<5 where !app.staticTexts[page.body].isHittable { scroll.swipeUp() }
            XCTAssertTrue(app.staticTexts[page.body].isHittable)
            XCTAssertTrue(action.isHittable)
            keepScreenshot(app, name: "hk-onboarding-large-type-page-\(index + 1)-scrolled")
            action.tap()
        }
        let close = app.buttons["membership-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 35))
        close.tap()
        let leave = app.buttons["membership-retention-close"]
        XCTAssertTrue(leave.waitForExistence(timeout: 10))
        leave.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["membership-close"].exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_RESET_LOCAL_STATE")
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["onboarding-next"].exists, "Completed onboarding must not return on relaunch")
    }

    private func configuredApp(screen: String? = nil, resetLocalState: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        if let screen {
            app.launchEnvironment["TALEFORK_UI_SCREEN"] = screen
        }
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
