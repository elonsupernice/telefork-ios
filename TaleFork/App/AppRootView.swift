import SwiftUI

struct AppRootView: View {
    @Environment(ProgressStore.self) private var store

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
        if ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] == "reader",
           let story = StoryLibrary.stories.first {
            StoryReaderView(story: story)
        } else {
            regularContent
        }
#else
        regularContent
#endif
    }

    @ViewBuilder
    private var regularContent: some View {
        if store.hasCompletedOnboarding {
            AppShellView()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }
}

struct AppShellView: View {
    @State private var selection: AppTab = .discover

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { ExploreView() }
                .tabItem { Label("tab.discover", systemImage: "sparkles.rectangle.stack") }
                .tag(AppTab.discover)

            NavigationStack { PathsView() }
                .tabItem { Label("tab.paths", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
                .tag(AppTab.paths)

            NavigationStack { VaultView() }
                .tabItem { Label("tab.vault", systemImage: "bookmark.square") }
                .tag(AppTab.vault)

            NavigationStack { SettingsView() }
                .tabItem { Label("tab.settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        .tint(TaleForkTheme.coral)
    }
}

private enum AppTab: Hashable {
    case discover
    case paths
    case vault
    case settings
}
