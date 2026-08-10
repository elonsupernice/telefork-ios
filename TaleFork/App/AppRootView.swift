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
        if ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] == "remote-player",
           isShowingPlaybackCheck {
            RemotePlaybackCheckView {
                isShowingPlaybackCheck = false
            }
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

#if DEBUG
private struct RemotePlaybackCheckView: View {
    @Environment(CatalogStore.self) private var catalog
    let onExit: () -> Void

    var body: some View {
        Group {
            if let drama = catalog.featured {
                DramaPlayerView(drama: drama, onExit: onExit)
            } else if let error = catalog.errorMessage {
                ContentUnavailableView("Playback check failed", systemImage: "wifi.exclamationmark", description: Text(error))
            } else {
                ProgressView("Connecting to live video…")
            }
        }
        .task { await catalog.load(force: true) }
    }
}
#endif

struct AppShellView: View {
    @State private var selection: AppTab

    init() {
        var initialTab = AppTab.discover
#if DEBUG
        switch ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] {
        case "paths": initialTab = .paths
        case "vault": initialTab = .vault
        case "settings": initialTab = .settings
        default: break
        }
#endif
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { ExploreView() }
                .tabItem { Label("tab.discover", systemImage: "sparkles.rectangle.stack") }
                .tag(AppTab.discover)

            NavigationStack { PathsView() }
                .tabItem { Label("tab.paths", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.paths)

            NavigationStack { VaultView() }
                .tabItem { Label("tab.vault", systemImage: "heart.text.square") }
                .tag(AppTab.vault)

            NavigationStack { SettingsView() }
                .tabItem { Label("tab.settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        .tint(TaleForkTheme.accentText)
    }
}

private enum AppTab: Hashable {
    case discover
    case paths
    case vault
    case settings
}
