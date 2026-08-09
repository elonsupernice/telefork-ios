import SwiftUI

@main
struct TaleForkApp: App {
    @State private var store = ProgressStore()
    @State private var catalog = CatalogStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .environment(catalog)
                .preferredColorScheme(preferredScheme)
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
