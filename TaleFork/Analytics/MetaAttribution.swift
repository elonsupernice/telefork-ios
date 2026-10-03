import AppTrackingTransparency
import FBSDKCoreKit
import Foundation
import UIKit

struct MetaEventContext: Sendable {
    let anonymousID: String
    let advertiserTrackingEnabled: Bool
    let applicationTrackingEnabled: Bool
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let deviceModel: String
    let locale: String
}

@MainActor
final class MetaAttribution {
    static let shared = MetaAttribution()

    private(set) var isConfigured = false
    private var didRequestDeferredAttribution = false
    private var isRequestingTrackingAuthorization = false

    private init() {}

    func start() {
        guard AttributionRuntime.shouldCollect(),
              Self.hasClientConfiguration(Bundle.main.infoDictionary ?? [:]) else { return }
        // Only installs/sessions go through the SDK. Generic automatic logging
        // also observes StoreKit purchases, which would duplicate server Purchase.
        Settings.shared.isAutoLogAppEventsEnabled = false
        Settings.shared.isAdvertiserIDCollectionEnabled = false
        isConfigured = true
    }

    static func hasClientConfiguration(_ info: [String: Any]) -> Bool {
        guard info["FacebookAppID"] as? String == "2221984505012142",
              let token = info["FacebookClientToken"] as? String else { return false }
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty && !normalized.contains("$(")
    }

    func activate() {
        guard isConfigured else { return }
        // activateApp publishes the SDK's deduplicated installation and session.
        AppEvents.shared.activateApp()
        fetchDeferredAttribution()
    }

    func fetchDeferredAttribution() {
        guard isConfigured, !didRequestDeferredAttribution else { return }
        didRequestDeferredAttribution = true
        AppLinkUtility.fetchDeferredAppLink { url, _ in
            guard let url else { return }
            Task { @MainActor in AttributionStore.shared.ingest(url: url) }
        }
    }

    func requestTrackingAuthorizationIfNeeded() async {
        guard #available(iOS 14, *), isConfigured, AttributionRuntime.shouldCollect(),
              UIApplication.shared.applicationState == .active,
              !isRequestingTrackingAuthorization else { return }
        let status = ATTrackingManager.trackingAuthorizationStatus
        if status == .notDetermined {
            isRequestingTrackingAuthorization = true
            defer { isRequestingTrackingAuthorization = false }
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
    }

    var needsTrackingAuthorization: Bool {
        guard #available(iOS 14, *) else { return false }
        return ATTrackingManager.trackingAuthorizationStatus == .notDetermined
    }

    var context: MetaEventContext {
        let info = Bundle.main
        let status: ATTrackingManager.AuthorizationStatus
        if #available(iOS 14, *) {
            status = ATTrackingManager.trackingAuthorizationStatus
        } else {
            status = .denied
        }
        let trackingAllowed = status == .authorized
        return MetaEventContext(
            anonymousID: isConfigured ? AppEvents.shared.anonymousID : "",
            advertiserTrackingEnabled: trackingAllowed,
            applicationTrackingEnabled: trackingAllowed,
            appVersion: info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            appBuild: info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            locale: Locale.current.identifier
        )
    }
}

final class TaleForkApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseAttribution.shared.start()
        MetaAttribution.shared.start()
        guard MetaAttribution.shared.isConfigured else { return true }
        let initialized = ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        return initialized
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AttributionStore.shared.ingest(url: url)
        guard MetaAttribution.shared.isConfigured else { return false }
        return ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation]
        )
    }
}
