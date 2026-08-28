import SwiftUI

struct SceneNotesView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @State private var playerDrama: Drama?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    SectionHeading(eyebrow: "scene.notes.eyebrow", title: "scene.notes.title")

                    Label("scene.notes.promise", systemImage: "bookmark.square.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if sortedMarks.isEmpty {
                        ContentUnavailableView(
                            "scene.notes.empty.title",
                            systemImage: "bookmark.slash",
                            description: Text("scene.notes.empty.body")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        ForEach(sortedMarks) { mark in
                            SceneMarkRow(
                                mark: mark,
                                isPlayable: playableDrama(for: mark) != nil,
                                onResume: { resume(mark) },
                                onDelete: { store.deleteSceneMark(id: mark.id) }
                            )
                        }
                    }
                }
                .padding(.horizontal, TaleForkTheme.horizontalMargin(for: proxy.size.width))
                .padding(.top, 20)
                .padding(.bottom, 112)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
        }
        .navigationTitle("tab.scene.notes")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $playerDrama) { drama in
            MomentPlayerView(drama: drama)
        }
        .task { await catalog.load() }
    }

    private var sortedMarks: [SceneMark] {
        store.sceneMarks.sorted { $0.createdAt > $1.createdAt }
    }

    private func playableDrama(for mark: SceneMark) -> Drama? {
        guard let drama = catalog.drama(id: mark.dramaID),
              drama.episode(id: mark.episodeID) != nil else { return nil }
        return drama
    }

    private func resume(_ mark: SceneMark) {
        guard let drama = playableDrama(for: mark) else { return }
        TactileFeedback.tap(enabled: store.preferences.tactileFeedbackEnabled)
        store.preparePlayback(for: mark, in: drama)
        playerDrama = drama
    }
}
