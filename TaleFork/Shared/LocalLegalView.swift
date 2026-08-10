import SwiftUI
import UIKit

struct LocalLegalView: View {
    enum Document {
        case privacy
        case terms

        var navigationTitle: LocalizedStringKey {
            self == .privacy ? "settings.privacy" : "settings.terms"
        }

        var bundledResource: String {
            self == .privacy ? "privacy-policy" : "terms-of-use"
        }
    }

    let document: Document
    @State private var content = AttributedString()
    @State private var didFail = false

    var body: some View {
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
        .background(PaperBackground())
        .navigationTitle(document.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: document.bundledResource) { loadDocument() }
    }

    @MainActor
    private func loadDocument() {
        guard let file = Bundle.main.url(forResource: document.bundledResource, withExtension: "html"),
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
