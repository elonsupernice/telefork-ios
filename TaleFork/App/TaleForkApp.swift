import SwiftUI

@main
struct TaleForkApp: App {
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
            AppRootView()
                .environment(store)
                .environment(catalog)
                .environment(membership)
                .preferredColorScheme(preferredScheme)
                .task { await membership.refreshEntitlements() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await membership.refreshEntitlements() }
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
