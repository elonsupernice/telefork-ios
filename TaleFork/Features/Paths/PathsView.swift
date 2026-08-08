import SwiftUI

struct PathsView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeading(eyebrow: "paths.eyebrow", title: "paths.title")
                    Text("paths.subtitle")
                        .foregroundStyle(.secondary)

                    ForEach(StoryLibrary.stories) { story in
                        let run = store.run(for: story)
                        NavigationLink {
                            StoryRouteDetailView(story: story)
                        } label: {
                            PathSummaryCard(story: story, run: run, hasStarted: store.runs[story.id] != nil)
                        }
                        .buttonStyle(.plain)
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
        .navigationTitle("tab.paths")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PathSummaryCard: View {
    let story: Story
    let run: StoryRun
    let hasStarted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: story.palette.startHex), Color(hex: story.palette.endHex)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: story.symbol)
                        .foregroundStyle(.white)
                        .font(.title2.weight(.semibold))
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title.resolved)
                        .font(.headline)
                    Text(hasStarted ? "paths.explored" : "paths.not.started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                stat(value: hasStarted ? "\(Set(run.visitedSceneIDs).count)" : "0", label: "paths.nodes")
                Divider().frame(height: 36)
                stat(value: "\(run.completedEndingIDs.count)/\(story.endings.count)", label: "story.endings")
                Divider().frame(height: 36)
                stat(value: "\(progress)%", label: "paths.progress")
            }

            ProgressView(value: Double(progress), total: 100)
                .tint(Color(hex: story.palette.accentHex))
        }
        .padding(18)
        .foregroundStyle(.primary)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progress: Int {
        guard hasStarted else { return 0 }
        return Int((Double(Set(run.visitedSceneIDs).count) / Double(story.scenes.count) * 100).rounded())
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StoryRouteDetailView: View {
    @Environment(ProgressStore.self) private var store
    let story: Story
    @State private var isReading = false

    var body: some View {
        let run = store.run(for: story)
        ScrollView {
            VStack(spacing: 20) {
                RouteMapView(story: story, run: run)
                Button {
                    store.start(story)
                    isReading = true
                } label: {
                    Label(store.runs[story.id] == nil ? "story.start" : "story.continue", systemImage: "book.pages")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaleForkTheme.coral)
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(PaperBackground())
        .navigationTitle(story.title.resolved)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isReading) {
            StoryReaderView(story: story)
        }
    }
}

struct RouteMapView: View {
    let story: Story
    let run: StoryRun

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(story.scenes.enumerated()), id: \.element.id) { index, scene in
                let visited = run.visitedSceneIDs.contains(scene.id)
                let current = run.currentSceneID == scene.id
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        RouteDot(isVisited: visited, isCurrent: current)
                            .padding(.top, 5)
                        if index < story.scenes.count - 1 {
                            Rectangle()
                                .fill(visited ? TaleForkTheme.mint.opacity(0.45) : TaleForkTheme.mist)
                                .frame(width: 2, height: 54)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(visited ? scene.heading.resolved : String(localized: "paths.unknown.node"))
                                .font(.headline)
                                .foregroundStyle(visited ? .primary : .secondary)
                            Spacer()
                            if scene.ending != nil {
                                Image(systemName: run.completedEndingIDs.contains(scene.id) ? "seal.fill" : "seal")
                                    .foregroundStyle(run.completedEndingIDs.contains(scene.id) ? TaleForkTheme.coral : .secondary)
                            }
                        }
                        Text(String(format: String(localized: "reader.chapter.format"), scene.chapter))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 28)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

