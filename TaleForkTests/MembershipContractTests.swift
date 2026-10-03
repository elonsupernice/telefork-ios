import Foundation
import Testing
import UIKit
import WebKit
@testable import TaleFork

struct MembershipContractTests {
    @MainActor @Test func hostedBridgeFollowsEitherServerHostWithoutHardcodingADomain() throws {
        for host in ["app.duanjufafafa.fun", "alipay-hk.syyc88.cn"] {
            let url = try #require(URL(string: "https://\(host)/tale-gateway/v2/membership/alipay-h5/tf_fixture?private=value"))
            let script = HostedWebPage.bridgeSource(for: url)
            #expect(script.contains("window.location.origin ==="))
            #expect(script.contains(host))
            #expect(script.contains("window.espJSBridge"))
            #expect(!script.contains("private=value"))
            #expect(!script.contains("tf_fixture"))
        }
    }

    @MainActor @Test func hostedBridgeOnlyAcceptsOrdinarySecureRedirects() {
        #expect(HostedWebPage.redirectURL(from: #"{"normalUrl":"https://secure.example.test/authorize"}"#)?.host == "secure.example.test")
        for body in [#"{"normalUrl":"http://secure.example.test/authorize"}"#,
                     #"{"normalUrl":"alipayhk://authorize"}"#,
                     #"{"normalUrl":"https://user:password@secure.example.test/"}"#,
                     #"{"applinkUrl":"alipayhk://authorize"}"#, "not-json", String(repeating: "a", count: 8193)] {
            #expect(HostedWebPage.redirectURL(from: body) == nil)
        }
    }

    @MainActor @Test func hostedMessagesAreRestrictedToTheInitialSecureOrigin() throws {
        let initial = try #require(URL(string: "https://alipay-hk.syyc88.cn/checkout"))
        let coordinator = HostedWebPage.Coordinator(initialURL: initial, onClose: {}, onError: { _ in }, onLoading: { _ in })
        #expect(coordinator.isTrustedOrigin(try #require(URL(string: "https://alipay-hk.syyc88.cn:443/result"))))
        for value in ["http://alipay-hk.syyc88.cn/", "https://alipay-hk.syyc88.cn:8443/",
                      "https://other.example.test/", "https://alipay-hk.syyc88.cn.other.example.test/"] {
            #expect(!coordinator.isTrustedOrigin(try #require(URL(string: value))))
        }
    }

    /// Exercises the actual WKUserScript and message handlers with local HTML.
    /// No server order, provider session, account or payment is created.
    @MainActor @Test func hostedWebKitActivatesAppLayoutAndReceivesThePagesOwnClose() async throws {
        let url = try #require(URL(string: "https://alipay-hk.syyc88.cn/local-container-fixture"))
        var ready = false
        var closed = false
        var errorMessage: String?
        let coordinator = HostedWebPage.Coordinator(initialURL: url, onClose: { closed = true },
                                                   onError: { errorMessage = $0 }, onLoading: { ready = !$0 })
        let configuration = HostedWebPage.configuration(for: url, coordinator: coordinator)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 760), configuration: configuration)
        coordinator.webView = webView
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        defer {
            webView.stopLoading()
            coordinator.stop()
            configuration.userContentController.removeScriptMessageHandler(forName: "espJSBridge")
            configuration.userContentController.removeScriptMessageHandler(forName: "taleCheckout")
        }
        coordinator.startLoading()
        webView.loadHTMLString("""
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
        <body><script>
        const native=!!window.espJSBridge;
        if(native)document.documentElement.classList.add('app-checkout');
        window.webkit.messageHandlers.taleCheckout.postMessage('ready');
        </script></body></html>
        """, baseURL: url)
        for _ in 0..<100 {
            if ready { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(ready)
        #expect(errorMessage == nil)
        let appLayout = try await webView.evaluateJavaScript("document.documentElement.classList.contains('app-checkout')") as? Bool
        #expect(appLayout == true)
        _ = try await webView.evaluateJavaScript("window.webkit.messageHandlers.taleCheckout.postMessage('close'); true")
        for _ in 0..<100 {
            if closed { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(closed)
    }

    @Test func countdownUsesAbsoluteDeadlineAndStopsAtZero() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let countdown = MembershipCountdown(expiresAt: now.addingTimeInterval(TimeInterval(MembershipCountdown.reservationDuration)))
        #expect(countdown.timeText(at: now) == "03:00")
        #expect(countdown.timeText(at: now.addingTimeInterval(5)) == "02:55")
        #expect(countdown.timeText(at: now.addingTimeInterval(60)) == "02:00")
        #expect(countdown.timeText(at: now.addingTimeInterval(179.5)) == "00:01")
        #expect(countdown.timeText(at: now.addingTimeInterval(180)) == "00:00")
        #expect(countdown.remainingSeconds(at: now.addingTimeInterval(900)) == 0)
    }

    @Test func cachedMembershipNeverSurvivesItsKnownExpiry() {
        #expect(MembershipStatusContent(vip: true, vipEndDate: "2099-01-01T00:00:00Z").isCurrentlyValid)
        #expect(!MembershipStatusContent(vip: true, vipEndDate: "2020-01-01T00:00:00Z").isCurrentlyValid)
        #expect(!MembershipStatusContent(vip: false, vipEndDate: nil).isCurrentlyValid)
    }

    @MainActor @Test func pageChangesKeepOneAbsoluteDeadline() {
        let membership = MembershipStore()
        membership.beginPaywallFlow()
        let deadline = membership.promotionDeadline
        membership.beginPaywallFlow()
        #expect(membership.promotionDeadline == deadline)
        membership.endPaywallFlow()
        #expect(membership.promotionDeadline == nil)
    }

    @MainActor @Test func windowShieldCoversNestedPagesAndRestoresWithoutAStateReset() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        // A hidden test window does not install its controller's view until
        // presentation. Build the real window hierarchy without stealing the
        // application's key window.
        window.addSubview(root.view)
        let paywall = MembershipProtectionAnchorView()
        let checkout = MembershipProtectionAnchorView()
        root.view.addSubview(paywall)
        root.view.addSubview(checkout)
        #expect(paywall.window === window)
        MembershipScreenProtection.shared.attach(paywall)
        MembershipScreenProtection.shared.attach(checkout)
        defer {
            MembershipScreenProtection.shared.detach(paywall)
            MembershipScreenProtection.shared.detach(checkout)
            window.isHidden = true
        }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        #expect(window.subviews.last?.accessibilityIdentifier == "membership-privacy-shield")
        MembershipScreenProtection.shared.detach(checkout)
        #expect(window.subviews.last?.accessibilityIdentifier == "membership-privacy-shield")
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        #expect(!window.subviews.contains { $0.accessibilityIdentifier == "membership-privacy-shield" })
    }
}
