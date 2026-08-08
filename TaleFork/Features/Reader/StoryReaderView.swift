import SwiftUI

struct StoryReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    let story: Story
    @State private var showRoute = false

    var body: some View {
        let run = store.run(for: story)
        let scene = story.scene(id: run.currentSceneID) ?? story.scenes[0]

        NavigationStack {
            ZStack {
                readerBackground
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            sceneHeader(scene: scene, run: run)
                            Text(scene.body.resolved)
                                .font(.system(.title3, design: .serif))
                                .lineSpacing(9)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)

                            if let quote = scene.quote?.resolved {
                                quoteCard(quote, scene: scene)
                            }

                            if let ending = scene.ending {
                                endingCard(ending, scene: scene)
                            } else {
                                choiceList(scene.choices)
                            }
                        }
                        .id(scene.id)
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 42)
                        .frame(maxWidth: 680)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: scene.id) { _, newValue in
                        if systemReduceMotion || store.preferences.reduceDecorativeMotion {
                            reader.scrollTo(newValue, anchor: .top)
                        } else {
                            withAnimation(.easeOut(duration: 0.45)) {
                                reader.scrollTo(newValue, anchor: .top)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(story.title.resolved)
                        .font(.headline)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("paths.route", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                        showRoute = true
                    }
                }
            }
            .sheet(isPresented: $showRoute) {
                NavigationStack {
                    RouteMapView(story: story, run: run)
                        .navigationTitle("paths.route")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("common.done") { showRoute = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var readerBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: story.palette.startHex).opacity(0.16),
                TaleForkTheme.paper.opacity(0.18),
                Color(hex: story.palette.endHex).opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func sceneHeader(scene: StoryScene, run: StoryRun) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: String(localized: "reader.chapter.format"), scene.chapter))
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(TaleForkTheme.coral)
                Spacer()
                Text("\(run.visitedSceneIDs.count) / \(story.scenes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(Set(run.visitedSceneIDs).count), total: Double(story.scenes.count))
                .tint(TaleForkTheme.coral)
            Text(scene.heading.resolved)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func quoteCard(_ quote: String, scene: StoryScene) -> some View {
        let saved = store.isQuoteSaved(storyID: story.id, sceneID: scene.id)
        return VStack(alignment: .leading, spacing: 14) {
            Text("“\(quote)”")
                .font(.system(.body, design: .serif).italic())
                .lineSpacing(4)
            Button {
                store.toggleQuote(storyID: story.id, sceneID: scene.id, text: quote)
            } label: {
                Label(saved ? "reader.saved" : "reader.save.quote", systemImage: saved ? "bookmark.fill" : "bookmark")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(TaleForkTheme.violet)
        }
        .padding(18)
        .background(TaleForkTheme.mist.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func choiceList(_ choices: [StoryChoice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("reader.choose")
                .font(.headline)
                .padding(.top, 6)
            ForEach(choices) { choice in
                Button {
                    Haptics.choice(enabled: store.preferences.hapticsEnabled)
                    store.choose(choice, in: story)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(TaleForkTheme.coral)
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(choice.title.resolved)
                                .font(.headline)
                            Text(choice.hint.resolved)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(TaleForkTheme.coral)
                    }
                    .foregroundStyle(.primary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(TaleForkTheme.coral.opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func endingCard(_ ending: StoryEnding, scene: StoryScene) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("reader.ending.unlocked", systemImage: ending.tone == .luminous ? "sun.max.fill" : "seal.fill")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(ending.tone == .luminous ? TaleForkTheme.coral : TaleForkTheme.violet)
            Text(ending.title.resolved)
                .font(.system(.title, design: .rounded, weight: .black))
            Text(ending.summary.resolved)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            HStack(spacing: 10) {
                Button {
                    store.restart(story)
                } label: {
                    Label("reader.replay", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaleForkTheme.violet)

                Button {
                    showRoute = true
                } label: {
                    Label("paths.route", systemImage: "point.3.connected.trianglepath.dotted")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            Haptics.completion(enabled: store.preferences.hapticsEnabled)
        }
    }
}

