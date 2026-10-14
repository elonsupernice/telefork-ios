import SwiftUI

struct AppRootView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @Environment(MembershipStore.self) private var membership
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingPlaybackCheck = true
    @State private var isShowingPostOnboardingMembership = false
    @State private var hasHandledStartupMembership = false
    @State private var hasResolvedStartupMembership = false
    @State private var hasPreloadedStartupMedia = false
#if DEBUG
    @State private var hasPresentedMembershipFixture = false
#endif

    var body: some View {
        ZStack {
            PaperBackground()
            appContent
        }
        .fullScreenCover(isPresented: $isShowingPostOnboardingMembership, onDismiss: {
            hasResolvedStartupMembership = true
        }) {
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
        .task(id: scenePhase) {
            guard scenePhase == .active else {
                if scenePhase == .background {
                    MembershipPreviewPreloader.shared.clearUnused()
                    hasPreloadedStartupMedia = false
                }
                return
            }
            await preloadStartupMedia()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            MembershipPreviewPreloader.shared.clearUnused()
            ArtworkCache.shared.clearMemory()
        }
        .onChange(of: membership.completedHostedCheckoutID) { _, checkoutID in
            guard checkoutID != nil else { return }
            isShowingPostOnboardingMembership = false
            hasHandledStartupMembership = true
            hasResolvedStartupMembership = true
            membership.endPaywallFlow()
        }
        .onChange(of: store.hasCompletedOnboarding, initial: true) { _, completed in
            if !completed {
                hasHandledStartupMembership = false
                hasResolvedStartupMembership = false
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
            if hasResolvedStartupMembership {
                TaleForkWorkspaceView()
            } else {
                startupBuffer
                    .task { await presentStartupMembershipIfNeeded() }
            }
        } else {
            OnboardingView(onFinished: presentMembershipAfterOnboarding)
                .transition(.opacity)
        }
    }

    private var startupBuffer: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    BrandMark(size: min(proxy.size.width * 0.28, 124))
                    Text("TaleFork")
                        .font(.system(size: min(proxy.size.width * 0.115, 46), weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.4)
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.65))
                        .accessibilityLabel(Text("app.startup.loading"))
                        .accessibilityIdentifier("startup-spinner")
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("startup-loading-screen")
    }

    private func presentMembershipAfterOnboarding() {
        // Finish the introduction directly into VIP, not the home screen
        // while catalog/entitlement requests are still running. The paywall
        // itself loads the current server route before showing any plans.
        guard !hasHandledStartupMembership else { return }
        hasHandledStartupMembership = true
        hasResolvedStartupMembership = membership.isSubscribed
        isShowingPostOnboardingMembership = !membership.isSubscribed
    }

    private func preloadStartupMedia() async {
        guard !hasPreloadedStartupMedia else { return }
        let preloader = MembershipPreviewPreloader.shared
        await catalog.load()
        await preloader.waitForInitialNetworkPath()
        guard !Task.isCancelled, !catalog.dramas.isEmpty else { return }
        let previews = MembershipPreviewSource.featuredDramas(in: catalog.dramas)
        let videoURLs = Array(previews.compactMap { MembershipPreviewSource.url(for: $0) }.prefix(2))
        if let first = videoURLs.first { preloader.stage(first) }
        await preloader.preload(Array(videoURLs.prefix(1)))
        guard !Task.isCancelled else { return }
        // Only first-screen home artwork and VIP posters, never every episode.
        let home = Array(catalog.dramas.filter { $0.episodes.count > 1 }.prefix(4))
        let continuing = store.history.compactMap { catalog.drama(id: $0.dramaID) }
            .first { $0.episodes.count > 1 }
        var coverURLs: [URL] = []
        for drama in home + Array(previews.prefix(2)) + (continuing.map { [$0] } ?? []) {
            if let url = drama.coverURL, !coverURLs.contains(url) { coverURLs.append(url) }
        }
        async let artwork: Void = ArtworkCache.shared.prefetch(coverURLs)
        await preloader.preload(Array(videoURLs.dropFirst()))
        await artwork
        if !Task.isCancelled { hasPreloadedStartupMedia = true }
    }

    private func presentStartupMembershipIfNeeded() async {
        // Process-local, not persisted: a killed/relaunched app presents again,
        // but dismissal, tab changes and foregrounding do not repeat it.
        guard !hasHandledStartupMembership else { return }
        hasHandledStartupMembership = true
        // Load the current v2 manifest first. PaymentRoute starts as Apple
        // StoreKit by design, so presenting the paywall before the manifest is
        // resolved can briefly (and permanently) show the wrong checkout
        // route for a paid acquisition. The catalog load also registers the
        // device pass and applies the channel's review/show-VIP settings.
        await catalog.load()
        await membership.refreshEntitlements()
        guard !Task.isCancelled, store.hasCompletedOnboarding else { return }
        if membership.isSubscribed {
            hasResolvedStartupMembership = true
        } else {
            // Keep the workspace unconstructed beneath VIP until it closes.
            // This prevents even a single home frame during cold-start routing.
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
    @Environment(MembershipStore.self) private var membership
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
        // Recreate tab/navigation state after a verified hosted activation:
        // no underlying VIP, player or detail screen should remain visible.
        .id(membership.completedHostedCheckoutID)
        .onChange(of: membership.completedHostedCheckoutID) { _, checkoutID in
            if checkoutID != nil { selection = .showcase }
        }
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
