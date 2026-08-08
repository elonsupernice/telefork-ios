import SwiftUI

struct ExploreView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    brandHeader

                    if let continuingStory {
                        ContinueRouteCard(story: continuingStory, run: store.run(for: continuingStory))
                    }

                    SectionHeading(eyebrow: "discover.collection.eyebrow", title: "discover.collection.title")

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: min(310, proxy.size.width - margin * 2)), spacing: 18)],
                        spacing: 22
                    ) {
                        ForEach(StoryLibrary.stories) { story in
                            NavigationLink(value: story) {
                                StoryDiscoveryCard(story: story, run: store.run(for: story))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    editorialNote
                }
                .padding(.horizontal, margin)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story)
        }
    }

    private var continuingStory: Story? {
        StoryLibrary.stories
            .filter { store.runs[$0.id] != nil && store.run(for: $0).currentSceneID != $0.entrySceneID }
            .sorted { store.run(for: $0).updatedAt > store.run(for: $1).updatedAt }
            .first
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            BrandMark(size: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text("TaleFork")
                    .font(.system(.title2, design: .rounded, weight: .black))
                Text("discover.brand.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.title2)
                .foregroundStyle(TaleForkTheme.coral)
                .accessibilityHidden(true)
        }
    }

    private var editorialNote: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(TaleForkTheme.mint)
                .font(.title2)
            VStack(alignment: .leading, spacing: 6) {
                Text("discover.offline.title")
                    .font(.headline)
                Text("discover.offline.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(TaleForkTheme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ContinueRouteCard: View {
    let story: Story
    let run: StoryRun

    var body: some View {
        NavigationLink(value: story) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: story.palette.accentHex).opacity(0.2))
                    Image(systemName: story.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(hex: story.palette.accentHex))
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 5) {
                    Text("discover.continue")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(TaleForkTheme.coral)
                    Text(story.title.resolved)
                        .font(.headline)
                    Text(String(format: String(localized: "discover.visited.format"), run.visitedSceneIDs.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(TaleForkTheme.coral)
            }
            .padding(18)
            .foregroundStyle(.primary)
            .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(TaleForkTheme.coral.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct StoryDiscoveryCard: View {
    let story: Story
    let run: StoryRun

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StoryArtwork(story: story, height: 210)
            HStack(alignment: .firstTextBaseline) {
                Text(story.genre.resolved)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(TaleForkTheme.coral)
                Spacer()
                if !run.completedEndingIDs.isEmpty {
                    Label("\(run.completedEndingIDs.count)/\(story.endings.count)", systemImage: "seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaleForkTheme.violet)
                }
            }
            Text(story.title.resolved)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(story.subtitle.resolved)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct StoryDetailView: View {
    @Environment(ProgressStore.self) private var store
    let story: Story
    @State private var isReading = false

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StoryArtwork(story: story, height: min(340, proxy.size.height * 0.4))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(story.genre.resolved.uppercased())
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(TaleForkTheme.coral)
                        Text(story.title.resolved)
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                        Text(story.synopsis.resolved)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                    }

                    HStack(spacing: 10) {
                        metric(symbol: "clock", value: "\(story.estimatedMinutes)", label: "story.minutes")
                        metric(symbol: "arrow.triangle.branch", value: "\(story.endings.count)", label: "story.endings")
                        metric(symbol: "point.3.connected.trianglepath.dotted", value: "\(story.scenes.count)", label: "story.scenes")
                    }

                    Button {
                        store.start(story)
                        isReading = true
                    } label: {
                        HStack {
                            Text(store.runs[story.id] == nil ? "story.start" : "story.continue")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 56)
                        .background(TaleForkTheme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Text("story.disclaimer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, margin)
                .padding(.vertical, 16)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isReading) {
            StoryReaderView(story: story)
        }
    }

    private func metric(symbol: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(TaleForkTheme.violet)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(TaleForkTheme.mist.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

