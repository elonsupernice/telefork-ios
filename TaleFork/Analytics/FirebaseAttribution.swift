import FirebaseAnalytics
import FirebaseCore
import Foundation

enum AttributionRuntime {
    static func shouldCollect(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
#if DEBUG
        // Offline fixtures and XCTest must never become real ad conversions.
        return environment["TALEFORK_ANALYTICS_DISABLED"] != "1"
            && environment["TALEFORK_OFFLINE_CATALOG"] != "1"
            && environment["TALEFORK_UI_SCREEN"] == nil
            && environment["XCTestConfigurationFilePath"] == nil
            && environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
#else
        return true
#endif
    }
}

@MainActor
final class FirebaseAttribution {
    static let shared = FirebaseAttribution()
    private(set) var isConfigured = false

    private init() {}

    var appID: String? {
        guard isConfigured, AttributionRuntime.shouldCollect() else { return nil }
        return FirebaseApp.app()?.options.googleAppID
    }

    var appInstanceID: String? {
        guard isConfigured, AttributionRuntime.shouldCollect(),
              let value = Analytics.appInstanceID(), !value.isEmpty else { return nil }
        return value
    }

    func sessionID() async -> Int64? {
        guard isConfigured, AttributionRuntime.shouldCollect() else { return nil }
        guard let value = try? await Analytics.sessionID(), value > 0,
              !Task.isCancelled, isConfigured, AttributionRuntime.shouldCollect() else { return nil }
        return value
    }

    func recordScreen(name: String, screenClass: String) {
        guard isConfigured, AttributionRuntime.shouldCollect() else { return }
        // SwiftUI does not provide a UIViewController for each selected tab.
        // This is a real page view, never a signup, signing or payment claim.
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass
        ])
    }

    func start() {
        guard !isConfigured, AttributionRuntime.shouldCollect(),
              let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path),
              options.bundleID == Bundle.main.bundleIdentifier,
              options.projectID == "talefork-44656" else { return }

        if FirebaseApp.allApps == nil || FirebaseApp.app() == nil {
            FirebaseApp.configure(options: options)
        }
        guard FirebaseApp.app()?.options.googleAppID == options.googleAppID else { return }
        // Measurement is enabled; advertising identifiers and personalization are not.
        // ATT is not a substitute for consent to personalized advertising.
        Analytics.setConsent([
            .analyticsStorage: .granted,
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied
        ])
        Analytics.setAnalyticsCollectionEnabled(true)
        isConfigured = true
    }
}
