import SwiftUI
import UIKit
import WebKit

struct LocalLegalView: View {
    enum Document {
        case privacy
        case terms

        var navigationTitle: LocalizedStringKey {
            self == .privacy ? "settings.privacy" : "settings.terms"
        }
    }

    let document: Document
    @State private var content = AttributedString()
    @State private var didFail = false
    @State private var isLoadingPrivacy = true
    @State private var privacyReloadID = UUID()

    var body: some View {
        Group {
            if document == .privacy {
                ZStack {
                    RemotePrivacyDocument(reloadID: privacyReloadID, isLoading: $isLoadingPrivacy, didFail: $didFail)
                    if didFail {
                        ContentUnavailableView {
                            Label("legal.unavailable.title", systemImage: "doc.badge.ellipsis")
                        } description: {
                            Text("legal.unavailable.body")
                        } actions: {
                            Button("common.retry") {
                                didFail = false
                                isLoadingPrivacy = true
                                privacyReloadID = UUID()
                            }
                        }
                        .background(PaperBackground())
                    } else if isLoadingPrivacy {
                        ProgressView("legal.loading")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            } else {
                ScrollView {
                    if didFail {
                        ContentUnavailableView(
                            "legal.unavailable.title",
                            systemImage: "doc.badge.ellipsis",
                            description: Text("legal.unavailable.body")
                        )
                        .frame(maxWidth: .infinity, minHeight: 360)
                    } else {
                        Text(content)
                            .textSelection(.enabled)
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 28)
                    }
                }
                .task { loadDocument() }
            }
        }
        .background(PaperBackground())
        .navigationTitle(document.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func loadDocument() {
        guard let file = Bundle.main.url(forResource: "terms-of-use", withExtension: "html"),
              let data = try? Data(contentsOf: file),
              let richText = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
              ) else {
            didFail = true
            return
        }
        content = AttributedString(richText)
        didFail = false
    }
}

private struct RemotePrivacyDocument: UIViewRepresentable {
    let reloadID: UUID
    @Binding var isLoading: Bool
    @Binding var didFail: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading, didFail: $didFail) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.accessibilityIdentifier = "privacy-policy-webview"
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.reloadID != reloadID else { return }
        context.coordinator.reloadID = reloadID
        let url = URL(string: "https://elonsupernice.github.io/telefork-ios/privacy-policy.html")!
        view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var reloadID: UUID?
        private let isLoading: Binding<Bool>
        private let didFail: Binding<Bool>

        init(isLoading: Binding<Bool>, didFail: Binding<Bool>) {
            self.isLoading = isLoading
            self.didFail = didFail
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            didFail.wrappedValue = false
            isLoading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.request.url?.scheme?.lowercased() == "https" else { return .cancel }
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                return .cancel
            }
            return .allow
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                fail()
                return .cancel
            }
            return .allow
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail() }

        private func report(_ error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { fail() }
        }

        private func fail() {
            isLoading.wrappedValue = false
            didFail.wrappedValue = true
        }
    }
}
