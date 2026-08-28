import SwiftUI

struct AppRootView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @State private var isShowingPlaybackCheck = true

    var body: some View {
        ZStack {
            PaperBackground()
            appContent
        }
        .animation(store.preferences.reduceDecorativeMotion ? nil : .easeInOut(duration: 0.35), value: store.hasCompletedOnboarding)
    }

    @ViewBuilder
    private var appContent: some View {
#if DEBUG
        switch ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] {
        case "playback-check" where isShowingPlaybackCheck:
            PlaybackCheckView {
                isShowingPlaybackCheck = false
            }
        case "onboarding":
            OnboardingView()
        case "showcase", "scene-notes", "collection", "studio":
            TaleForkWorkspaceView()
        default:
            regularContent
        }
#else
        regularContent
#endif
    }

    @ViewBuilder
    private var regularContent: some View {
        if store.hasCompletedOnboarding {
            TaleForkWorkspaceView()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }
}

#if DEBUG
private struct PlaybackCheckView: View {
    @Environment(CatalogStore.self) private var catalog
    let onExit: () -> Void

    var body: some View {
        Group {
            if let drama = catalog.featured {
                MomentPlayerView(drama: drama, onExit: onExit)
            } else if let error = catalog.errorMessage {
                ContentUnavailableView("discover.connection.title", systemImage: "wifi.exclamationmark", description: Text(error))
            } else {
                ProgressView("discover.loading")
            }
        }
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .task { await catalog.load(force: true) }
    }
}
#endif

struct TaleForkWorkspaceView: View {
    @State private var selection: WorkspaceTab

    init() {
        var initialTab = WorkspaceTab.showcase
#if DEBUG
        switch ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] {
        case "scene-notes": initialTab = .sceneNotes
        case "collection": initialTab = .collection
        case "studio": initialTab = .studio
        default: break
        }
#endif
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("tab.showcase", systemImage: "sparkles.tv", value: WorkspaceTab.showcase) {
                NavigationStack { ExploreView() }
            }

            Tab("tab.scene.notes", systemImage: "bookmark.square", value: WorkspaceTab.sceneNotes) {
                NavigationStack { SceneNotesView() }
            }

            Tab("tab.collection", systemImage: "rectangle.stack", value: WorkspaceTab.collection) {
                NavigationStack { VaultView() }
            }

            Tab("tab.studio", systemImage: "slider.horizontal.3", value: WorkspaceTab.studio) {
                NavigationStack { StoryStudioView() }
            }
        }
        .tint(TaleForkTheme.accentText)
    }
}

private enum WorkspaceTab: Hashable {
    case showcase
    case sceneNotes
    case collection
    case studio
}
