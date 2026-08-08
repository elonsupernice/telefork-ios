import SwiftUI
import WebKit

struct LocalLegalView: View {
    enum Document {
        case privacy
        case terms

        var title: LocalizedStringKey {
            switch self {
            case .privacy: "settings.privacy"
            case .terms: "settings.terms"
            }
        }

        var fileName: String {
            switch self {
            case .privacy: "privacy-policy"
            case .terms: "terms-of-use"
            }
        }
    }

    let document: Document

    var body: some View {
        LegalWebView(fileName: document.fileName)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalWebView: UIViewRepresentable {
    let fileName: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

