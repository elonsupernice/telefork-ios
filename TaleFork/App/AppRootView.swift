import SwiftUI

struct AppRootView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @State private var isShowingPlaybackCheck = true
    @State private var isShowingPostOnboardingMembership = false
#if DEBUG
    @State private var hasPresentedMembershipFixture = false
#endif

    var body: some View {
        ZStack {
            PaperBackground()
            appContent
        }
        .fullScreenCover(isPresented: $isShowingPostOnboardingMembership) {
#if DEBUG
            if ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] == "hosted-result-check" {
                HostedPageView(url: URL(string: "https://result.example.test/fixture")!)
            } else {
                MembershipPaywallView()
            }
#else
            MembershipPaywallView()
#endif
        }
        .animation(store.preferences.reduceDecorativeMotion ? nil : .easeInOut(duration: 0.35), value: store.hasCompletedOnboarding)
        .onChange(of: store.hasCompletedOnboarding, initial: true) { _, completed in
            if !completed {
                FirebaseAttribution.shared.recordScreen(name: "onboarding", screenClass: "OnboardingView")
            }
        }
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
            OnboardingView(onFinished: presentMembershipAfterOnboarding)
        case "membership", "hosted-result-check":
            // Match real entry semantics so simulator X/back tests exercise
            // dismissal, rather than calling dismiss on an inline root view.
            TaleForkWorkspaceView()
                .task {
                    guard !hasPresentedMembershipFixture else { return }
                    hasPresentedMembershipFixture = true
                    isShowingPostOnboardingMembership = true
                }
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
            OnboardingView(onFinished: presentMembershipAfterOnboarding)
                .transition(.opacity)
        }
    }

    private func presentMembershipAfterOnboarding() {
        // Load the current v2 manifest first. PaymentRoute starts as Apple
        // StoreKit by design, so presenting the paywall before the manifest is
        // resolved can briefly (and permanently) show the wrong checkout
        // route for a paid acquisition. The catalog load also registers the
        // device pass and applies the channel's review/show-VIP settings.
        Task { @MainActor in
            await catalog.load()
            isShowingPostOnboardingMembership = true
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
        .onChange(of: selection, initial: true) { _, tab in
            recordSelectedScreen(tab)
        }
    }

    private func recordSelectedScreen(_ tab: WorkspaceTab) {
        let screen: (name: String, className: String)
        switch tab {
        case .showcase: screen = ("showcase", "ExploreView")
        case .sceneNotes: screen = ("scene_notes", "SceneNotesView")
        case .collection: screen = ("collection", "VaultView")
        case .studio: screen = ("preferences", "StoryStudioView")
        }
        FirebaseAttribution.shared.recordScreen(name: screen.name, screenClass: screen.className)
    }
}

private enum WorkspaceTab: Hashable {
    case showcase
    case sceneNotes
    case collection
    case studio
}
