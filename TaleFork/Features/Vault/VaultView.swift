import SwiftUI

struct VaultView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    SectionHeading(eyebrow: "vault.eyebrow", title: "vault.title")
                    completionOverview

                    SectionHeading(eyebrow: "vault.quotes.eyebrow", title: "vault.quotes.title")
                    if store.savedQuotes.isEmpty {
                        emptyQuotes
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(store.savedQuotes) { quote in
                                SavedQuoteCard(quote: quote) {
                                    store.removeQuote(id: quote.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, margin)
                .padding(.top, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
        }
        .navigationTitle("tab.vault")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var completionOverview: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(TaleForkTheme.mist, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: completionRatio)
                    .stroke(TaleForkTheme.coral, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((completionRatio * 100).rounded()))%")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 7) {
                Text("vault.endings.title")
                    .font(.headline)
                Text(String(format: String(localized: "vault.endings.format"), unlockedEndingCount, totalEndingCount))
                    .font(.title3.weight(.bold))
                Text("vault.endings.body")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyQuotes: some View {
        VStack(spacing: 14) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 38))
                .foregroundStyle(TaleForkTheme.violet)
            Text("vault.quotes.empty.title")
                .font(.headline)
            Text("vault.quotes.empty.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(TaleForkTheme.mist.opacity(0.42), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var totalEndingCount: Int {
        StoryLibrary.stories.reduce(0) { $0 + $1.endings.count }
    }

    private var unlockedEndingCount: Int {
        store.runs.values.reduce(0) { $0 + $1.completedEndingIDs.count }
    }

    private var completionRatio: Double {
        guard totalEndingCount > 0 else { return 0 }
        return Double(unlockedEndingCount) / Double(totalEndingCount)
    }
}

private struct SavedQuoteCard: View {
    let quote: SavedQuote
    let onDelete: () -> Void

    var body: some View {
        let story = StoryLibrary.story(id: quote.storyID)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: story?.symbol ?? "book")
                    .foregroundStyle(TaleForkTheme.coral)
                Text(story?.title.resolved ?? "TaleFork")
                    .font(.caption.weight(.bold))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text("common.delete"))
            }
            Text("“\(quote.text)”")
                .font(.system(.body, design: .serif).italic())
                .lineSpacing(4)
        }
        .padding(18)
        .background(.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

