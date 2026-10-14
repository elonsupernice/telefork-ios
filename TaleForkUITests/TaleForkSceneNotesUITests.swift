import Foundation
import UIKit
import XCTest

@MainActor
final class TaleForkSceneNotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWholeAppIsBlackInSystemCapture() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        defer { app.terminate() }

        for screen in ["membership", "studio"] {
            app.launchEnvironment["TALEFORK_UI_SCREEN"] = screen
            app.launch()
            if screen == "membership" {
                XCTAssertTrue(app.buttons["membership-close"].waitForExistence(timeout: 15))
            } else {
                XCTAssertTrue(app.tabBars.buttons["偏好"].waitForExistence(timeout: 15))
            }
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(screen)-system-capture-must-be-black"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertTrue(screenshot.image.isCaptureBlack, "System capture exposed \(screen) App content")
            app.terminate()
        }
    }

    func testActiveScreenRecordingUsesAnOpaqueBlackShield() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_FORCE_SCREEN_CAPTURED"] = "1"
        app.launch()
        defer { app.terminate() }

        let shield = app.otherElements["membership-privacy-shield"]
        XCTAssertTrue(shield.waitForExistence(timeout: 15))
        XCTAssertEqual(shield.frame, app.windows.firstMatch.frame)
        XCTAssertTrue(XCUIScreen.main.screenshot().image.isCaptureBlack)
    }

    func testPrivacyPolicyLoadsWebsiteInsideApp() throws {
        let app = XCUIApplication(bundleIdentifier: "com.talefork.storypaths")
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "studio"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        app.launch()
        defer { app.terminate() }

        let privacy = app.buttons["隱私政策"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 10))
        privacy.tap()
        let document = app.webViews["privacy-policy-webview"]
        XCTAssertTrue(document.waitForExistence(timeout: 10))
        XCTAssertTrue(document.staticTexts["1. 儲存在裝置上的資料"].waitForExistence(timeout: 30))
        XCTAssertNotEqual(XCUIApplication(bundleIdentifier: "com.apple.mobilesafari").state, .runningForeground)
        keepScreenshot(app, name: "privacy-policy-public-website-inside-app")

        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["使用條款"].tap()
        let terms = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "TaleFork Terms of Use")).firstMatch
        XCTAssertTrue(terms.waitForExistence(timeout: 10))
        XCTAssertFalse(app.webViews.firstMatch.exists)
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
        let app = routingFixtureApp()
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
        XCTAssertFalse(app.descendants(matching: .any)["membership-reservation-countdown"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["membership-promotion-countdown"].exists)
        keepScreenshot(app, name: "hosted-page-loading-traditional")

        let ready = app.webViews.buttons["完成測試載入"]
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        ready.tap()
        XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hosted-page-close"].isHittable)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "為你保留 3 分鐘")).firstMatch.exists)
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

    /// Local server and HTML only. Never authorizes a wallet or pays money.
    func testHostedActivationAutomaticallyReturnsHomeWithoutSearch() async throws {
        for screen in ["membership", "studio"] {
            try await configureRoutingFixture(review: false, allowFixtureCheckout: true)
            let app = routingFixtureApp()
            app.launchEnvironment["TALEFORK_UI_SCREEN"] = screen
            app.launchEnvironment["TALEFORK_UI_HOSTED_RESULT_FIXTURE"] = "1"
            app.launch()
            if screen == "studio" {
                let open = app.buttons["profile-membership-open"]
                XCTAssertTrue(open.waitForExistence(timeout: 15))
                open.tap()
            }
            let purchase = app.buttons["hosted-membership-open"]
            XCTAssertTrue(purchase.waitForExistence(timeout: 25))
            purchase.tap()
            XCTAssertTrue(app.webViews.staticTexts["付款成功"].waitForExistence(timeout: 10))
            // Mere H5 success text must NOT activate VIP or dismiss checkout.
            XCTAssertTrue(app.buttons["hosted-page-close"].exists)
            try await configureRoutingFixture(review: false, vip: true,
                                              vipEndDate: "2099-01-01T00:00:00Z",
                                              allowFixtureCheckout: true)
            XCTAssertTrue(app.webViews.firstMatch.waitForNonExistence(timeout: 12))
            let home = app.tabBars.buttons["放映台"]
            XCTAssertTrue(home.waitForExistence(timeout: 10))
            XCTAssertTrue(home.isSelected, "Successful checkout must select home even when opened from preferences")
            XCTAssertFalse(app.buttons["hosted-membership-open"].exists)
            XCTAssertFalse(app.textFields.firstMatch.exists, "Home search must be removed")
            XCTAssertFalse(app.searchFields.firstMatch.exists)
            app.terminate()
        }
        try await configureRoutingFixture(review: false)
    }

    func testClosingUnpaidHostedCheckoutDoesNotCompleteMembership() async throws {
        try await configureRoutingFixture(review: false, allowFixtureCheckout: true)
        let app = routingFixtureApp()
        app.launchEnvironment["TALEFORK_UI_HOSTED_RESULT_FIXTURE"] = "1"
        app.launch()
        defer { app.terminate() }
        let purchase = app.buttons["hosted-membership-open"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 25))
        purchase.tap()
        XCTAssertTrue(app.webViews.staticTexts["付款成功"].waitForExistence(timeout: 10))
        app.buttons["hosted-page-close"].tap()
        XCTAssertTrue(purchase.waitForExistence(timeout: 12), "Closing without confirmed membership must preserve the paywall")
        XCTAssertFalse(app.webViews.firstMatch.exists)
        try await configureRoutingFixture(review: false)
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
        app.launchEnvironment["TALEFORK_ANALYTICS_DISABLED"] = "1"
        app.launchEnvironment["TALEFORK_SERVICE_BASE_URL"] = "http://127.0.0.1:18642/"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK"]
        return app
    }

    /// The loopback fixture rejects checkout: these taps cannot create a real order.
    func testMembershipWholeButtonRespondsAndCountdownSitsAboveIt() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launch()
        defer { app.terminate() }
        let action = app.buttons["hosted-membership-open"]
        XCTAssertTrue(action.waitForExistence(timeout: 30))
        XCTAssertTrue(action.isHittable)
        let countdown = app.descendants(matching: .any)["membership-promotion-countdown"].firstMatch
        XCTAssertTrue(countdown.exists)
        XCTAssertGreaterThanOrEqual(countdown.frame.minY, app.buttons["hosted-offer-2019"].frame.maxY)
        XCTAssertLessThanOrEqual(countdown.frame.maxY, action.frame.minY)
        XCTAssertEqual(countdown.frame.maxX, action.frame.maxX, accuracy: 1)
        keepScreenshot(app, name: "membership-countdown-above-action-trailing")

        let (beforeData, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let before = try XCTUnwrap(JSONSerialization.jsonObject(with: beforeData) as? [String: Any])
        let initialRequests = try XCTUnwrap(before["checkoutRequests"] as? Int)
        for x in [0.05, 0.95, 0.5] {
            action.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).tap()
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 8), "The whole visible gold button must invoke checkout, not just its text")
            alert.buttons.firstMatch.tap()
        }
        let (afterData, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: afterData) as? [String: Any])
        XCTAssertEqual(after["checkoutRequests"] as? Int, initialRequests + 3, "Each tap invokes the existing action exactly once")
    }

    func testFooterLegalTextOnlyNavigatesAndEmptySpaceOpensCheckout() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launch()
        defer { app.terminate() }
        let action = app.buttons["hosted-membership-open"]
        XCTAssertTrue(action.waitForExistence(timeout: 25))

        func requestCount() async throws -> Int {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
            let state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            return try XCTUnwrap(state["checkoutRequests"] as? Int)
        }
        let initial = try await requestCount()
        for id in ["membership-purchase-details", "membership-terms-link", "membership-privacy-link"] {
            let link = app.buttons[id]
            XCTAssertTrue(link.isHittable)
            link.tap()
            XCTAssertFalse(app.alerts.firstMatch.exists)
            XCTAssertFalse(app.webViews["hosted-membership-page"].exists)
            let legalRequests = try await requestCount()
            XCTAssertEqual(legalRequests, initial, "Protocol text must never invoke checkout")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(action.waitForExistence(timeout: 5))
        }

        let terms = app.buttons["membership-terms-link"].frame
        let points = [CGPoint(x: terms.midX, y: terms.minY - 5),
                      CGPoint(x: terms.midX, y: terms.maxY + 5),
                      // Stay inside the physical screen's rounded corners.
                      CGPoint(x: action.frame.minX + 3, y: terms.midY),
                      CGPoint(x: action.frame.maxX - 3, y: terms.midY),
                      CGPoint(x: terms.minX - 8, y: terms.midY)]
        for point in points {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: point.x, dy: point.y)).tap()
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 8), "Blank footer taps must invoke the checkout, not a protocol")
            alert.buttons.firstMatch.tap()
        }
        let footerRequests = try await requestCount()
        XCTAssertEqual(footerRequests, initial + points.count)
    }

    /// Wait for the real three-minute deadline; no shortened production timer or checkout.
    func testCountdownExpiryKeepsBenefitsReservedCopy() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launch()
        defer { app.terminate() }
        let action = app.buttons["hosted-membership-open"]
        XCTAssertTrue(action.waitForExistence(timeout: 30))
        let countdown = app.descendants(matching: .any)["membership-promotion-countdown"].firstMatch
        XCTAssertTrue(countdown.exists)
        XCTAssertEqual(countdown.label, "限時優惠價，為你保留 3 分鐘")

        let expired = NSPredicate(format: "label == %@ AND value == %@", "好權益，繼續為你保留", "00:00")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: expired, evaluatedWith: countdown)], timeout: 185), .completed)
        XCTAssertTrue(action.isHittable)
        XCTAssertTrue(action.isEnabled)
        XCTAssertLessThanOrEqual(countdown.frame.maxY, action.frame.minY)
        keepScreenshot(app, name: "membership-expired-benefits-still-reserved")
        try await assertFixtureNeverOrdered()
    }

    private func configureRoutingFixture(review: Bool, delay: Int = 0, vip: Bool = false, vipEndDate: String? = nil,
                                         allowFixtureCheckout: Bool = false) async throws {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:18642/fixture")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.httpBody = try JSONSerialization.data(withJSONObject: ["review": review, "delay": delay, "fail": false,
                                                                      "vip": vip, "vipEndDate": vipEndDate as Any? ?? NSNull(),
                                                                      "allowFixtureCheckout": allowFixtureCheckout])
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    private func assertFixtureNeverOrdered() async throws {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["checkoutRequests"] as? Int, 0, "Viewing or switching plans must never create an order")
    }

    /// No UI-screen shortcut: exercise the regular root's process-local startup path.
    func testStartupBufferHidesHomeUntilVIPRoutingResolves() async throws {
        try await configureRoutingFixture(review: false, delay: 8)
        let app = routingFixtureApp()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_UI_SCREEN")
        app.launchEnvironment["TALEFORK_UI_PREVIEW"] = "1"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_RESET_LOCAL_STATE"] = "1"
        app.launch()
        defer { app.terminate() }
        let loading = app.descendants(matching: .any)["startup-loading-screen"].firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 5))
        let spinner = app.descendants(matching: .any)["startup-spinner"].firstMatch
        XCTAssertTrue(spinner.exists)
        XCTAssertFalse(app.staticTexts["載入中…"].exists)
        XCTAssertTrue(app.staticTexts["TaleFork"].exists)
        XCTAssertEqual(spinner.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 2)
        XCTAssertGreaterThan(spinner.frame.midY, app.windows.firstMatch.frame.height * 0.85)
        XCTAssertFalse(app.tabBars.firstMatch.exists, "Home must not be constructed during startup routing")
        keepScreenshot(app, name: "startup-buffer-before-vip-no-home-flash")
        for _ in 0..<5 {
            XCTAssertFalse(app.tabBars.firstMatch.exists)
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(app.buttons["hosted-membership-open"].waitForExistence(timeout: 35))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["VIP 會員禮遇"].exists)
        XCTAssertTrue(app.staticTexts["選擇會籍計劃"].exists)
        keepScreenshot(app, name: "startup-direct-vip-hong-kong-copy")
        app.buttons["membership-close"].tap()
        app.buttons["membership-retention-close"].tap()
        XCTAssertTrue(app.tabBars.buttons["放映台"].waitForExistence(timeout: 5))
        try await configureRoutingFixture(review: false)
        try await assertFixtureNeverOrdered()
    }

    func testColdLaunchReturnsToVIPButForegroundDoesNotRepeatIt() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_UI_SCREEN")
        app.launchEnvironment["TALEFORK_UI_PREVIEW"] = "1"
        app.launch()
        defer { app.terminate() }
        let action = app.buttons["hosted-membership-open"]
        XCTAssertTrue(action.waitForExistence(timeout: 35))
        keepScreenshot(app, name: "cold-launch-nonmember-vip")
        app.buttons["membership-close"].tap()
        app.buttons["membership-retention-close"].tap()
        XCTAssertTrue(action.waitForNonExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertFalse(action.waitForExistence(timeout: 3), "Returning from background must not repeat the paywall")
        app.terminate()
        app.launch()
        XCTAssertTrue(action.waitForExistence(timeout: 35), "A new app process must present VIP again")
        keepScreenshot(app, name: "relaunch-nonmember-vip")
    }

    func testColdLaunchSkipsActiveVIPButShowsExpiredVIP() async throws {
        try await configureRoutingFixture(review: false, vip: true, vipEndDate: "2099-01-01T00:00:00Z")
        let app = routingFixtureApp()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_UI_SCREEN")
        app.launchEnvironment["TALEFORK_UI_PREVIEW"] = "1"
        app.launch()
        defer { app.terminate() }
        let preferences = app.tabBars.buttons["偏好"]
        XCTAssertTrue(preferences.waitForExistence(timeout: 35))
        preferences.tap()
        XCTAssertTrue(app.staticTexts["VIP 已生效"].waitForExistence(timeout: 35), "Wait for the confirmed server entitlement")
        XCTAssertFalse(app.buttons["hosted-membership-open"].exists)
        keepScreenshot(app, name: "cold-launch-active-vip-skipped")

        app.terminate()
        try await configureRoutingFixture(review: false, vip: true, vipEndDate: "2000-01-01T00:00:00Z")
        app.launch()
        XCTAssertTrue(app.buttons["hosted-membership-open"].waitForExistence(timeout: 35))
        keepScreenshot(app, name: "cold-launch-expired-vip-presented")
        try await configureRoutingFixture(review: false)
    }

    func testFirstLaunchKeepsOnboardingBeforeStartupVIP() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_UI_SCREEN")
        app.launchEnvironment["TALEFORK_RESET_LOCAL_STATE"] = "1"
        app.launch()
        defer { app.terminate() }
        let page = app.staticTexts["onboarding-page-count"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        XCTAssertEqual(page.label, "1 / 4")
        XCTAssertFalse(app.buttons["hosted-membership-open"].exists)
        for expected in 2...4 {
            app.buttons["onboarding-next"].tap()
            XCTAssertEqual(page.label, "\(expected) / 4")
        }
        app.buttons["onboarding-begin"].tap()
        XCTAssertTrue(app.buttons["hosted-membership-open"].waitForExistence(timeout: 35))
        app.buttons["membership-close"].tap()
        app.buttons["membership-retention-close"].tap()
        XCTAssertFalse(app.buttons["hosted-membership-open"].waitForExistence(timeout: 3), "Onboarding completion must not enqueue two paywalls")
    }

    /// Deliberately slow local startup requests cannot expose home after onboarding.
    func testOnboardingEntersVIPImmediatelyWhileManifestIsSlow() async throws {
        try await configureRoutingFixture(review: false, delay: 8)
        let app = routingFixtureApp()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_UI_SCREEN")
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_RESET_LOCAL_STATE"] = "1"
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        for _ in 0..<3 { app.buttons["onboarding-next"].tap() }
        app.buttons["onboarding-begin"].tap()
        XCTAssertTrue(app.navigationBars["VIP 會籍"].waitForExistence(timeout: 2),
                      "VIP must open immediately, before slow startup requests finish")
        XCTAssertFalse(app.tabBars.firstMatch.isHittable, "Home must not be the next usable screen")
        keepScreenshot(app, name: "onboarding-direct-vip-hk-title-slow-network")
        XCTAssertTrue(app.buttons["hosted-membership-open"].waitForExistence(timeout: 35))
        app.buttons["membership-close"].tap()
        app.buttons["membership-retention-close"].tap()
        XCTAssertTrue(app.tabBars.buttons["放映台"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["hosted-membership-open"].waitForExistence(timeout: 3))
        try await configureRoutingFixture(review: false)
    }

    /// Real StoreKit products exercise the production Product rendering path.
    /// No purchase, credentials, or App Store Connect setting is changed.
    func testGoldAppleThreePortraitPlansAndRetention() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
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
        let countdown = app.descendants(matching: .any)["membership-promotion-countdown"].firstMatch
        XCTAssertTrue(countdown.exists)
        XCTAssertLessThanOrEqual(countdown.frame.maxY, action.frame.minY)
        XCTAssertEqual(countdown.frame.maxX, action.frame.maxX, accuracy: 1)
        let renewal = app.staticTexts["apple-membership-renewal"]
        XCTAssertTrue(renewal.isHittable)
        let benefits = app.otherElements["membership-benefits-card"]
        XCTAssertTrue(benefits.staticTexts["高清睇劇"].exists)
        XCTAssertTrue(benefits.staticTexts["熱劇搶先睇"].exists)
        XCTAssertFalse(benefits.staticTexts["片單收藏"].exists)
        XCTAssertFalse(benefits.staticTexts["個人場記"].exists)
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
    func testMembershipOpenButtonBreathesWithoutMoving() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
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
        try await Task.sleep(for: .milliseconds(800))
        let frameTwo = action.screenshot()
        XCTAssertNotEqual(frameOne.pngRepresentation, frameTwo.pngRepresentation,
                          "The capsule and label must visibly breathe while the full-width tap target stays fixed")
        XCTAssertEqual(action.frame, originalFrame, "Breathing must not move or resize the button")
        for (index, frame) in [frameOne, frameTwo].enumerated() {
            let attachment = XCTAttachment(screenshot: frame)
            attachment.name = "membership-breathing-light-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        // Sample two full 1.6-second reference-style scale cycles, without purchasing.
        for index in 0..<8 {
            let attachment = XCTAttachment(screenshot: action.screenshot())
            attachment.name = "membership-breathing-and-sheen-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
            try await Task.sleep(for: .milliseconds(400))
        }
        XCTAssertEqual(action.frame, originalFrame)
        keepScreenshot(app, name: "membership-breathing-paywall")
        app.buttons["membership-close"].tap()
        let retentionAction = app.buttons["membership-retention-continue"]
        XCTAssertTrue(retentionAction.waitForExistence(timeout: 5))
        XCTAssertTrue(retentionAction.isHittable)
        let retentionFrame = retentionAction.frame
        let retentionOne = retentionAction.screenshot()
        try await Task.sleep(for: .milliseconds(800))
        let retentionTwo = retentionAction.screenshot()
        XCTAssertNotEqual(retentionOne.pngRepresentation, retentionTwo.pngRepresentation)
        XCTAssertEqual(retentionAction.frame, retentionFrame)
        keepScreenshot(app, name: "membership-breathing-retention")
        app.terminate()
    }

    func testMembershipBreathingStopsForReducedMotionPreference() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "studio"
        app.launch()
        defer { app.terminate() }
        let setting = app.switches["減少裝飾動畫"]
        reveal(setting, in: app.scrollViews.firstMatch)
        XCTAssertTrue(setting.exists)
        let original = setting.value as? String
        if original != "1" { setting.tap() }
        app.terminate()
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launch()
        let action = app.buttons["hosted-membership-open"]
        XCTAssertTrue(action.waitForExistence(timeout: 30))
        let still = action.screenshot()
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(still.pngRepresentation, action.screenshot().pngRepresentation,
                       "Reduced decorative motion must leave a steady, full-size button")
        keepScreenshot(app, name: "membership-reduced-motion-steady-action")
        app.terminate()
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "studio"
        app.launch()
        reveal(setting, in: app.scrollViews.firstMatch)
        if setting.value as? String != original { setting.tap() }
    }

    /// Requires the loopback audio-fixture.py and its certificate in the QA
    /// simulator. Plays a real MP4 with an audio track, never a live order.
    func testMembershipPreviewAutoplaysAudiblyAndPausesForCheckout() throws {
        let app = routingFixtureApp()
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "studio"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launch()
        defer { app.terminate() }

        let nextEpisode = app.switches["自動播放下一集"]
        reveal(nextEpisode, in: app.scrollViews.firstMatch)
        XCTAssertTrue(nextEpisode.exists)
        if nextEpisode.value as? String == "1" { nextEpisode.tap() }
        XCTAssertEqual(nextEpisode.value as? String, "0")
        app.terminate()
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launch()

        let video = app.descendants(matching: .any)["membership-paywall-video"].firstMatch
        assertAudiblePreview(video)
        let carousel = app.otherElements["membership-exclusive-carousel"]
        let firstTitle = carousel.label
        carousel.swipeLeft()
        let changed = NSPredicate { _, _ in carousel.label != firstTitle }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: changed, evaluatedWith: carousel)], timeout: 5), .completed)
        assertAudiblePreview(video)

        app.buttons["hosted-membership-open"].tap()
        let paused = NSPredicate { _, _ in
            let value = video.value as? String ?? ""
            return value.hasPrefix("paused:") && value.contains("allowed=false")
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: paused, evaluatedWith: video)], timeout: 4), .completed)
        let done = app.alerts.buttons["完成"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        assertAudiblePreview(video)

        app.buttons["membership-close"].tap()
        let retention = app.descendants(matching: .any)["membership-retention-video"].firstMatch
        assertAudiblePreview(retention)
        XCTAssertFalse(video.exists, "The hidden VIP preview must not remain exposed or own playback")
        XCUIDevice.shared.press(.home)
        app.activate()
        assertAudiblePreview(retention)
        keepScreenshot(app, name: "membership-audible-retention-local-media")
        app.buttons["membership-retention-close"].tap()
        XCTAssertTrue(retention.waitForNonExistence(timeout: 5))
        XCTAssertFalse(video.exists)
    }

    func testAppleMembershipPreviewAutoplaysAudibly() throws {
        let app = routingFixtureApp()
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launch()
        defer { app.terminate() }
        assertAudiblePreview(app.descendants(matching: .any)["membership-paywall-video"].firstMatch)
        app.buttons["membership-close"].tap()
        assertAudiblePreview(app.descendants(matching: .any)["membership-retention-video"].firstMatch)
    }

    /// Local HTTPS fixture proves media/artwork requests occur during bundled
    /// onboarding, then the visible preview reuses the prepared AVPlayer.
    func testOnboardingPreloadsVIPVideoAndHomeArtwork() async throws {
        let (baselineData, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let baseline = try XCTUnwrap(JSONSerialization.jsonObject(with: baselineData) as? [String: Any])
        let initialMedia = baseline["mediaRequests"] as? Int ?? 0
        let initialArtwork = baseline["artworkRequests"] as? Int ?? 0
        let initialLineup = baseline["lineupRequests"] as? Int ?? 0
        let app = routingFixtureApp()
        app.launchEnvironment.removeValue(forKey: "TALEFORK_UI_SCREEN")
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "0"
        app.launchEnvironment["TALEFORK_RESET_LOCAL_STATE"] = "1"
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["membership-promotion-countdown"].exists)
        var before: [String: Any] = [:]
        for _ in 0..<100 {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
            before = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            if (before["artworkRequests"] as? Int ?? 0) >= initialArtwork + 3
                && (before["mediaRequests"] as? Int ?? 0) >= initialMedia + 2 { break }
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertGreaterThanOrEqual(before["mediaRequests"] as? Int ?? 0, initialMedia + 2)
        XCTAssertEqual(before["artworkRequests"] as? Int, initialArtwork + 3)
        XCTAssertEqual(before["lineupRequests"] as? Int, initialLineup + 1, "Concurrent startup/onboarding loads must coalesce")
        let events = before["events"] as? [[String: Any]] ?? []
        let initialEvents = (baseline["events"] as? [[String: Any]] ?? []).count
        XCTAssertEqual(events.dropFirst(initialEvents).first?["kind"] as? String, "media", "VIP media must start before artwork")
        // Give the real preroll its bounded six-second preparation window.
        try await Task.sleep(for: .seconds(2))
        keepScreenshot(app, name: "onboarding-while-next-screen-media-preloads")
        for _ in 0..<3 { app.buttons["onboarding-next"].tap() }
        app.buttons["onboarding-begin"].tap()
        let video = app.descendants(matching: .any)["membership-paywall-video"].firstMatch
        assertAudiblePreview(video)
        XCTAssertTrue((video.value as? String ?? "").contains("preloaded=true"))
        let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(after["artworkRequests"] as? Int, initialArtwork + 3, "VIP/home must consume the same artwork cache")
        XCTAssertEqual(after["lineupRequests"] as? Int, initialLineup + 1)
        XCTAssertEqual(after["checkoutRequests"] as? Int, baseline["checkoutRequests"] as? Int)
        let evidence = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        evidence.name = "startup-prefetch-local-request-counts"
        evidence.lifetime = .keepAlways
        add(evidence)
        keepScreenshot(app, name: "vip-reuses-onboarding-preloaded-player")
        app.buttons["membership-close"].tap()
        app.buttons["membership-retention-close"].tap()
        XCTAssertTrue(app.tabBars.buttons["放映台"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "home-reuses-onboarding-prefetched-artwork")
        let (homeData, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:18642/fixture")!)
        let home = try XCTUnwrap(JSONSerialization.jsonObject(with: homeData) as? [String: Any])
        XCTAssertEqual(home["artworkRequests"] as? Int, initialArtwork + 3)
    }

    private func assertAudiblePreview(_ video: XCUIElement) {
        assertVideoAdvances(video, minimum: 1, timeout: 20)
        let value = video.value as? String ?? ""
        XCTAssertTrue(value.contains("muted=false"), value)
        XCTAssertTrue(value.contains("volume=1.0"), value)
        XCTAssertTrue(value.contains("audio=AVAudioSessionCategoryPlayback"), value)
        XCTAssertTrue(value.contains("mode=AVAudioSessionModeMoviePlayback"), value)
        let evidence = XCTAttachment(string: value)
        evidence.name = "audible-preview-player-clock-and-audio-session"
        evidence.lifetime = .keepAlways
        add(evidence)
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

    func testGoldMembershipAccessibilityLayout() async throws {
        try await configureRoutingFixture(review: false)
        let app = routingFixtureApp()
        app.launchEnvironment["TALEFORK_UI_SCREEN"] = "membership"
        app.launchEnvironment["TALEFORK_OFFLINE_CATALOG"] = "1"
        app.launchEnvironment["TALEFORK_TEST_APPLE_PAYWALL"] = "1"
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_HK", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let weekly = app.buttons["apple-offer-com.talefork.storypaths.vip.weekly"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 75))
        let benefits = app.otherElements["membership-benefits-card"]
        XCTAssertTrue(benefits.staticTexts["高清睇劇"].exists)
        XCTAssertTrue(benefits.staticTexts["熱劇搶先睇"].exists)
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
        for label in ["連續觀看", "高清睇劇", "熱劇搶先睇"] {
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

    /// Gesture QA uses offline episodes and a loopback entitlement service.
    /// No production account, video download or payment is involved.
    func testPlayerVerticalSwipesAndControlsWithOfflineEpisodes() async throws {
        try await configureRoutingFixture(review: false)
        let app = launchGesturePlayer(episodeNumber: 1)
        defer { app.terminate() }
        assertPlayerEpisode(1, in: app)
        swipePlayer(in: app, upward: false)
        assertPlayerEpisode(1, in: app) // First episode must not wrap.
        swipePlayer(in: app, upward: true)
        assertPlayerEpisode(2, in: app)
        swipePlayer(in: app, upward: true)
        assertPlayerEpisode(3, in: app)
        swipePlayer(in: app, upward: false)
        assertPlayerEpisode(2, in: app)

        // Horizontal scrubbing and small movements are not episode swipes.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.32))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.33)))
        assertPlayerEpisode(2, in: app)
        let shortStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        shortStart.press(forDuration: 0.05, thenDragTo: shortStart.withOffset(CGVector(dx: 0, dy: -20)))
        assertPlayerEpisode(2, in: app)
        // A sub-threshold movement can remain a tap and hide controls.
        if !app.buttons["scene-mark-player-action"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).tap()
        }
        XCTAssertTrue(app.buttons["scene-mark-player-action"].waitForExistence(timeout: 3))
        let progress = app.sliders["player-progress"]
        XCTAssertTrue(progress.isHittable)
        progress.adjust(toNormalizedSliderPosition: 0.65)
        assertPlayerEpisode(2, in: app)

        // Controls can still be hidden by a tap; swiping also works when hidden.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).tap()
        XCTAssertTrue(app.buttons["scene-mark-player-action"].waitForNonExistence(timeout: 3))
        swipePlayer(in: app, upward: true)
        assertPlayerEpisode(3, in: app)
        XCTAssertTrue(app.buttons["scene-mark-player-action"].waitForExistence(timeout: 3))
        app.buttons["Pause"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Play"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Episodes"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Episodes"].waitForExistence(timeout: 3))
        app.swipeUp() // Scroll the sheet; it must not change the episode behind it.
        app.buttons["Done"].tap()
        assertPlayerEpisode(3, in: app)
        keepScreenshot(app, name: "player-vertical-swipes-controls-preserved")
        try await assertFixtureNeverOrdered()
    }

    func testPlayerSwipeToLockedEpisodePreservesVIPGate() async throws {
        try await configureRoutingFixture(review: false)
        let app = launchGesturePlayer(episodeNumber: 10)
        defer { app.terminate() }
        assertPlayerEpisode(10, in: app)
        swipePlayer(in: app, upward: true)
        XCTAssertTrue(app.buttons["membership-close"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["hosted-offer-2019"].waitForExistence(timeout: 15))
        keepScreenshot(app, name: "player-swipe-episode-eleven-vip-gate")
        app.buttons["membership-close"].tap()
        XCTAssertTrue(app.buttons["membership-retention-close"].waitForExistence(timeout: 5))
        app.buttons["membership-retention-close"].tap()
        assertPlayerEpisode(10, in: app)
        swipePlayer(in: app, upward: false)
        assertPlayerEpisode(9, in: app)
        try await assertFixtureNeverOrdered()
    }

    func testPlayerVIPLastEpisodeSwipeDoesNotWrap() async throws {
        try await configureRoutingFixture(review: false, vip: true,
                                          vipEndDate: "2099-12-31T23:59:59Z")
        let app = launchGesturePlayer(episodeNumber: 12, activeVIP: true)
        defer { app.terminate() }
        assertPlayerEpisode(12, in: app)
        swipePlayer(in: app, upward: true)
        assertPlayerEpisode(12, in: app)
        XCTAssertFalse(app.buttons["membership-close"].exists)
        swipePlayer(in: app, upward: false)
        assertPlayerEpisode(11, in: app)
        swipePlayer(in: app, upward: true)
        assertPlayerEpisode(12, in: app)
        keepScreenshot(app, name: "player-swipe-last-episode-no-wrap")
        try await assertFixtureNeverOrdered()
    }

    private func launchGesturePlayer(episodeNumber: Int, activeVIP: Bool = false) -> XCUIApplication {
        let app = configuredApp(screen: activeVIP ? "studio" : "showcase", resetLocalState: true)
        app.launchEnvironment["TALEFORK_ANALYTICS_DISABLED"] = "1"
        app.launchEnvironment["TALEFORK_SERVICE_BASE_URL"] = "http://127.0.0.1:18642/"
        app.launch()
        if activeVIP {
            XCTAssertTrue(app.staticTexts["VIP active"].waitForExistence(timeout: 30))
            app.tabBars.buttons["Showcase"].tap()
        }
        let story = app.buttons["The Lantern Room"].firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 8))
        story.tap()
        if episodeNumber == 1 {
            let start = app.buttons["Start Episode 1"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        } else {
            let episode = app.buttons["episode-\(episodeNumber)-button"]
            for _ in 0..<10 where !episode.isHittable { app.swipeUp() }
            XCTAssertTrue(episode.isHittable)
            episode.tap()
        }
        return app
    }

    private func swipePlayer(in app: XCUIApplication, upward: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.62 : 0.3))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.3 : 0.62))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func assertPlayerEpisode(_ number: Int, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let video = app.descendants(matching: .any)["player-video"].firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 5), file: file, line: line)
        let expected = NSPredicate(format: "value == %@", "Episode \(number)")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: expected, evaluatedWith: video)], timeout: 3),
                       .completed, "Expected episode \(number), got \(video.value ?? "missing")", file: file, line: line)
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

private extension UIImage {
    var isCaptureBlack: Bool {
        guard let cgImage else { return false }
        let points = [
            CGPoint(x: size.width * 0.25, y: size.height * 0.25),
            CGPoint(x: size.width * 0.75, y: size.height * 0.25),
            CGPoint(x: size.width * 0.5, y: size.height * 0.5),
            CGPoint(x: size.width * 0.25, y: size.height * 0.75),
            CGPoint(x: size.width * 0.75, y: size.height * 0.75)
        ]
        return points.allSatisfy { point in
            let scaleX = CGFloat(cgImage.width) / size.width
            let scaleY = CGFloat(cgImage.height) / size.height
            let x = min(max(Int(point.x * scaleX), 0), cgImage.width - 1)
            let y = min(max(Int(point.y * scaleY), 0), cgImage.height - 1)
            var pixel: [UInt8] = [0, 0, 0, 0]
            guard let context = CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.translateBy(x: CGFloat(-x), y: CGFloat(y - cgImage.height + 1))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return pixel[0] <= 8 && pixel[1] <= 8 && pixel[2] <= 8
        }
    }
}
