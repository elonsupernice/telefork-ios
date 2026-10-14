import SwiftUI

@main
struct TaleForkApp: App {
    @UIApplicationDelegateAdaptor(TaleForkApplicationDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: ProgressStore
    @State private var catalog: CatalogStore
    @State private var membership: MembershipStore

    init() {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["TALEFORK_RESET_LOCAL_STATE"] == "1" {
            ProgressStore.clearStoredStateForTesting()
        }
        let catalog = environment["TALEFORK_OFFLINE_CATALOG"] == "1"
            ? CatalogStore(service: OfflineCatalogService())
            : CatalogStore()
        _catalog = State(initialValue: catalog)
#else
        _catalog = State(initialValue: CatalogStore())
#endif
        _store = State(initialValue: ProgressStore())
        _membership = State(initialValue: MembershipStore())
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()

                CaptureHiddenContainer {
                    AppRootView()
                        .environment(store)
                        .environment(catalog)
                        .environment(membership)
                        .membershipCaptureProtected(allowed: false)
                        .preferredColorScheme(preferredScheme)
                        .task { await membership.refreshEntitlements() }
                        .onOpenURL { url in
                            _ = appDelegate.application(UIApplication.shared, open: url)
                        }
                        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                            guard let url = activity.webpageURL else { return }
                            _ = appDelegate.application(UIApplication.shared, open: url)
                        }
                        .task(id: scenePhase) {
                            guard scenePhase == .active else { return }
                            MetaAttribution.shared.activate()
                            await MetaAttribution.shared.requestTrackingAuthorizationIfNeeded()
                            guard !Task.isCancelled else { return }
                            await TaleForkService.shared.bindSDKContextIfAvailable()
                        }
                        .onChange(of: scenePhase) { _, phase in
                            guard phase == .active else { return }
                            Task { await membership.refreshEntitlements() }
                        }
                }
            }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch store.preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
