import SwiftUI
import WebKit

/// A standard, full-screen web container, not a wallet/payment SDK.
struct HostedPageView: View {
    @Environment(MembershipStore.self) private var membership
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var errorMessage: String?
    @State private var reloadID = UUID()
    @State private var isLoading = true
    let url: URL
    var checkoutID: String? = nil
    var onConfirmed: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HostedWebPage(url: url, reloadID: reloadID, onClose: { dismiss() }, onError: { errorMessage = $0 },
                          onLoading: { if isLoading != $0 { isLoading = $0 } })
            if isLoading && errorMessage == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("membership.hosted.loading")
                        .font(.subheadline)
                        .accessibilityIdentifier("hosted-page-loading")
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            if let errorMessage {
                VStack(spacing: 16) {
                    Text(verbatim: errorMessage).multilineTextAlignment(.center)
                    Button("common.retry") { self.errorMessage = nil; isLoading = true; reloadID = UUID() }
                    Button("common.close") { dismiss() }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .accessibilityIdentifier("hosted-page-error")
            }
            // Keep a native escape after redirects too: a remote result page
            // may not provide a close control or share the trusted bridge origin.
            if errorMessage == nil {
                Button("common.close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hosted-page-close")
            }
        }
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .interactiveDismissDisabled()
        .task(id: scenePhase == .active ? checkoutID : nil) {
            guard let checkoutID else { return }
            // Poll only while this checkout is visible and foregrounded.
            // The provider callback can arrive after its H5 success screen.
            while !Task.isCancelled {
                if await membership.confirmHostedMembership() {
                    guard !Task.isCancelled, self.checkoutID == checkoutID else { return }
                    onConfirmed()
                    dismiss()
                    return
                }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
}

struct HostedWebPage: UIViewRepresentable {
    let url: URL
    let reloadID: UUID
    let onClose: () -> Void
    let onError: (String) -> Void
    let onLoading: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(initialURL: url, onClose: onClose, onError: onError, onLoading: onLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = Self.configuration(for: url, coordinator: context.coordinator)
        let view = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = view
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .white
        view.scrollView.backgroundColor = .white
        view.accessibilityIdentifier = "hosted-membership-page"
        return view
    }

    /// Compatibility with the hosted page's existing web-message contract.
    /// No native provider session, authorization or charging API is included.
    static func configuration(for url: URL, coordinator: Coordinator) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.addUserScript(WKUserScript(
            source: bridgeSource(for: url), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.add(coordinator, name: "espJSBridge")
        configuration.userContentController.add(coordinator, name: "taleCheckout")
        return configuration
    }

    static func bridgeSource(for url: URL) -> String {
        var origin = URLComponents(url: url, resolvingAgainstBaseURL: false)
        origin?.path = ""
        origin?.query = nil
        origin?.fragment = nil
        if origin?.port == 443 { origin?.port = nil }
        guard let value = origin?.string, let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else { return "" }
        return """
        if (window.location.origin === \(encoded)) {
            window.espJSBridge = { sdkRedirect: function(message) {
                window.webkit.messageHandlers.espJSBridge.postMessage(message);
            }};
        }
        """
    }

    static func acceptsNavigation(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host != nil && url.user == nil && url.password == nil
    }

    static func redirectURL(from body: String) -> URL? {
        guard body.utf8.count <= 8192, let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let address = object["normalUrl"] as? String, let url = URL(string: address),
              acceptsNavigation(url) else { return nil }
        return url
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.reloadID != reloadID else { return }
        context.coordinator.reloadID = reloadID
        context.coordinator.startLoading()
#if DEBUG
        if ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] == "hosted-result-check"
            || ProcessInfo.processInfo.environment["TALEFORK_UI_HOSTED_RESULT_FIXTURE"] == "1" {
            // Offline UI fixture: no order/session or provider request is ever created.
            let waitsForReady = ProcessInfo.processInfo.environment["TALEFORK_UI_HOSTED_WAIT_FOR_READY"] == "1"
            let content = waitsForReady
                ? "<button onclick=\"this.remove();window.webkit.messageHandlers.taleCheckout.postMessage('ready')\">完成測試載入</button>"
                : "<h1>付款成功</h1><p>VIP 已開通，請關閉此頁面回到 TaleFork。</p>"
            let readyScript = waitsForReady ? "" : "window.webkit.messageHandlers.taleCheckout.postMessage('ready')"
            view.loadHTMLString("""
            <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body style="font-family:system-ui;padding:40px 24px;background:#f6f1e8">
            \(content)
            <script>\(readyScript)</script></body></html>
            """, baseURL: url)
            return
        }
#endif
        view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        coordinator.stop()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "espJSBridge")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "taleCheckout")
        view.configuration.userContentController.removeAllUserScripts()
        view.navigationDelegate = nil
        view.uiDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var reloadID: UUID?
        weak var webView: WKWebView?
        private let initialURL: URL
        private var loadingTask: Task<Void, Never>?
        private var isStopped = false
        let onClose: () -> Void
        let onError: (String) -> Void
        let onLoading: (Bool) -> Void

        init(initialURL: URL, onClose: @escaping () -> Void, onError: @escaping (String) -> Void,
             onLoading: @escaping (Bool) -> Void) {
            self.initialURL = initialURL
            self.onClose = onClose
            self.onError = onError
            self.onLoading = onLoading
        }

        func startLoading() {
            loadingTask?.cancel()
            onLoading(true)
            loadingTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.fail(String(localized: "membership.presentation.timeout"))
            }
        }

        func stop() {
            isStopped = true
            loadingTask?.cancel()
            loadingTask = nil
        }

        func isTrustedOrigin(_ origin: URL) -> Bool {
            HostedWebPage.acceptsNavigation(origin)
                && origin.host?.lowercased() == initialURL.host?.lowercased()
                && (origin.port ?? 443) == (initialURL.port ?? 443)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !isStopped, message.frameInfo.isMainFrame,
                  let origin = message.frameInfo.request.url, isTrustedOrigin(origin),
                  let body = message.body as? String else { return }
            if message.name == "taleCheckout" {
                switch body {
                case "ready": ready()
                case "close": onClose()
                case "failed": fail(String(localized: "membership.purchase.failed"))
                default: break
                }
            } else if message.name == "espJSBridge" {
                guard let target = HostedWebPage.redirectURL(from: body) else {
                    fail(String(localized: "membership.purchase.failed"))
                    return
                }
                startLoading()
                webView?.load(URLRequest(url: target, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
            }
        }

        private func ready() {
            guard !isStopped else { return }
            loadingTask?.cancel()
            loadingTask = nil
            onLoading(false)
        }

        private func fail(_ message: String) {
            guard !isStopped else { return }
            ready()
            onError(message)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // Keep checkout inside the app. Never dispatch custom wallet
            // schemes or put the app's access pass into web requests.
            guard !isStopped, let url = navigationAction.request.url,
                  HostedWebPage.acceptsNavigation(url) else {
                return .cancel
            }
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                return .cancel
            } else {
                return .allow
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // New-window requests are loaded once by the navigation delegate.
            return nil
        }

        func webViewDidClose(_ webView: WKWebView) { onClose() }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // The owned page reports readiness after its hosted component is
            // ready; a subsequent HTTPS page has ordinary WebKit readiness.
            if let url = webView.url, !isTrustedOrigin(url) { ready() }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                fail(String(localized: "membership.purchase.failed"))
                return .cancel
            } else {
                return .allow
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            fail(String(localized: "membership.purchase.failed"))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }

        private func report(_ error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { fail(error.localizedDescription) }
        }
    }
}
