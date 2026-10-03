import Foundation
import Observation
import UIKit

enum ServiceRoute: String, CaseIterable {
    case heartbeat = "tale-gateway/v2/heartbeat"
    case devicePass = "tale-gateway/v2/identity/device-pass"
    case launchManifest = "tale-gateway/v2/launch/manifest"
    case lineup = "tale-gateway/v2/screenings/lineup"
    case search = "tale-gateway/v2/screenings/search"
    case membershipStatus = "tale-gateway/v2/membership/status"
    case membershipOffers = "tale-gateway/v2/membership/offers"
    case membershipCheckout = "tale-gateway/v2/membership/checkout"
    case appleContext = "tale-gateway/v2/membership/apple/context"
    case appleTransactions = "tale-gateway/v2/membership/apple/transactions"
    case sdkContext = "tale-gateway/v2/analytics/sdk-context"
}

/// Measurement context only. The server owns event meaning, amount and time.
struct SDKContextReport: Encodable, Sendable {
    let metaAnonymousID: String?
    let firebaseAppInstanceID: String?
    let metaAdvertiserTrackingEnabled: Bool
    let metaApplicationTrackingEnabled: Bool
    let googleAnalyticsStorageGranted: Bool
    let googleAdUserDataGranted: Bool
    let googleAdPersonalizationGranted: Bool
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let deviceModel: String
    let locale: String
    let firebaseSessionID: Int64?
    let firebaseAppID: String?
}

enum TaleForkServiceError: LocalizedError {
    case invalidResponse
    case unauthorized
    case identityRemoved
    case rejected(String)
    case decoding
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "service.invalid.response")
        case .unauthorized: return String(localized: "service.session.expired")
        case .identityRemoved: return String(localized: "service.session.expired")
        case let .rejected(detail): return detail
        case .decoding: return String(localized: "service.invalid.data")
        case let .unavailable(detail): return detail
        }
    }
}

private struct MobileEnvelope<Content: Decodable>: Decodable {
    let outcome: String
    let detail: String?
    let content: Content?
}

private extension KeyedDecodingContainer {
    func tolerantString(_ key: Key) -> String {
        if let text = try? decode(String.self, forKey: key) { return text }
        if let integer = try? decode(Int64.self, forKey: key) { return String(integer) }
        return ""
    }

    func tolerantInteger(_ key: Key, fallback: Int) -> Int {
        if let integer = try? decode(Int.self, forKey: key) { return integer }
        if let text = try? decode(String.self, forKey: key), let integer = Int(text) { return integer }
        return fallback
    }

    func tolerantArray<Element: Decodable>(_ type: Element.Type, _ key: Key) -> [Element] {
        (try? decode([Element].self, forKey: key)) ?? []
    }
}

private struct DevicePassContent: Decodable, Sendable {
    let audienceKey: String
    let accessPass: String

    init(audienceKey: String, accessPass: String) {
        self.audienceKey = audienceKey
        self.accessPass = accessPass
    }

    private enum CodingKeys: String, CodingKey {
        case audienceKey
        case accessPass
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        audienceKey = values.tolerantString(.audienceKey)
        accessPass = values.tolerantString(.accessPass)
    }
}

struct CatalogBootstrap {
    let userID: String
    let dramas: [Drama]
}

@MainActor
protocol CatalogServing: AnyObject {
    func bootstrap() async throws -> CatalogBootstrap
    func search(_ keyword: String) async throws -> [Drama]
    func deleteAccount() async throws
    func clearLocalIdentity() async throws
}

private struct IdentityRemovalContent: Decodable {
    let identityRemoved: Bool
}

private struct LaunchManifestContent: Decodable, Sendable {
    let assetRoot: URL
    let promotionID: String?
    let vipScreenShot: Bool?
    let reviewModel: Bool?
    let showVip: Bool?
    let allowedCheckoutHosts: [String]

    private enum CodingKeys: String, CodingKey {
        case assetRoot
        case promotionID = "promotionId"
        case vipScreenShot
        case reviewModel, showVip, allowedCheckoutHosts
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let raw = values.tolerantString(.assetRoot)
        guard let url = URL(string: raw), !raw.isEmpty else { throw TaleForkServiceError.decoding }
        assetRoot = url
        promotionID = try? values.decodeIfPresent(String.self, forKey: .promotionID)
        vipScreenShot = try? values.decodeIfPresent(Bool.self, forKey: .vipScreenShot)
        reviewModel = try values.decodeIfPresent(Bool.self, forKey: .reviewModel)
        showVip = try values.decodeIfPresent(Bool.self, forKey: .showVip)
        allowedCheckoutHosts = try values.decodeIfPresent([String].self, forKey: .allowedCheckoutHosts) ?? []
    }
}

private struct ScreeningContent: Decodable {
    let stories: [RemoteStory]

    private enum CodingKeys: String, CodingKey { case stories }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        stories = values.tolerantArray(RemoteStory.self, .stories)
    }
}

private struct RemoteStory: Decodable {
    let storyKey: String
    let displayTitle: String
    let storyBlurb: String
    let artworkLink: URL?
    let chapterTotal: Int
    let displayRank: Int

    private enum CodingKeys: String, CodingKey {
        case storyKey
        case displayTitle
        case storyBlurb
        case artworkLink
        case chapterTotal
        case displayRank
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        storyKey = values.tolerantString(.storyKey)
        displayTitle = values.tolerantString(.displayTitle)
        storyBlurb = values.tolerantString(.storyBlurb)
        artworkLink = URL(string: values.tolerantString(.artworkLink))
        chapterTotal = max(values.tolerantInteger(.chapterTotal, fallback: 1), 1)
        displayRank = values.tolerantInteger(.displayRank, fallback: 0)
    }

    func appDrama(assetRoot: URL) -> Drama {
        let episodes = (1...chapterTotal).map { number in
            let episodeTitle = String(format: String(localized: "remote.episode.title"), number)
            return DramaEpisode(
                id: "\(storyKey)-\(number)",
                number: number,
                title: .server(episodeTitle),
                sceneCaption: .server(storyBlurb),
                clipName: "",
                videoURL: assetRoot
                    .appendingPathComponent("stories")
                    .appendingPathComponent(storyKey)
                    .appendingPathComponent("reels")
                    .appendingPathComponent(String(number))
                    .appendingPathComponent("playback.mp4"),
                durationSeconds: 1
            )
        }
        return Drama(
            id: storyKey,
            title: .server(displayTitle),
            subtitle: .server(storyBlurb),
            storySummary: .server(storyBlurb),
            posterImageName: "",
            coverURL: artworkLink,
            accentHex: accentColor,
            availability: .available,
            entryEpisodeID: episodes[0].id,
            episodes: episodes
        )
    }

    private var accentColor: String {
        let palette = ["E6A84C", "59C4BE", "6570C5", "E7796B", "60A5A8"]
        let seed = storyKey.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return palette[abs(seed) % palette.count]
    }
}

private enum JSONScalar: Encodable {
    case text(String)
    case number(Int)

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case let .text(text): try value.encode(text)
        case let .number(number): try value.encode(number)
        }
    }
}

@MainActor
@Observable
final class TaleForkService: CatalogServing {
    static let shared = TaleForkService()

    private let baseURL: URL
    private let sessionStore = SessionIdentityStore.shared
    private var accessPass = ""
    private var audienceKey = ""
    @ObservationIgnored private var sessionTask: Task<DevicePassContent, Error>?
    @ObservationIgnored private var manifestTask: Task<LaunchManifestContent, Error>?
    @ObservationIgnored private var isBindingSDKContext = false
    @ObservationIgnored private var lastBoundSDKContext: Data?
    @ObservationIgnored private var lastBoundSDKContextAudience = ""
    var currentAudienceKey: String { audienceKey }
    private(set) var hasLoadedMembershipConfiguration = false
    private(set) var membershipScreenshotsAllowed = false
    private(set) var membershipPresentationConfiguration = MembershipPresentationConfiguration(
        reviewModel: nil, showVip: nil, allowedHosts: [])
    private(set) var appleAccountToken: UUID?
    private var appleVerificationEnabled = false

    var hasExplicitRetentionAttribution: Bool {
        let snapshot = AttributionStore.shared.snapshot
        return [snapshot.promotionID, snapshot.adID].contains { value in
            guard let value else { return false }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !normalized.isEmpty && normalized != "0"
        }
    }

    init() {
#if DEBUG
        if let override = ProcessInfo.processInfo.environment["TALEFORK_SERVICE_BASE_URL"],
           let url = URL(string: override) {
            baseURL = url
        } else {
            baseURL = URL(string: "https://app.duanjufafafa.fun/")!
        }
#else
        baseURL = URL(string: "https://app.duanjufafafa.fun/")!
#endif
    }

    func bootstrap() async throws -> CatalogBootstrap {
        _ = try await ensureSession()
        let manifest = try await loadMembershipConfiguration()
        let screening: ScreeningContent = try await post(.lineup, body: ["maximumStories": .number(50)])
        return CatalogBootstrap(
            userID: audienceKey,
            dramas: screening.stories.map { $0.appDrama(assetRoot: manifest.assetRoot) }
        )
    }

    func search(_ keyword: String) async throws -> [Drama] {
        guard !accessPass.isEmpty else {
            return try await bootstrap().dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(keyword)
            }
        }
        let manifest = try await loadMembershipConfiguration()
        let screening: ScreeningContent = try await post(
            .search,
            body: ["searchText": .text(keyword), "maximumStories": .number(50)]
        )
        return screening.stories.map { $0.appDrama(assetRoot: manifest.assetRoot) }
    }

    func deleteAccount() async throws {
        guard !accessPass.isEmpty else {
            try await clearLocalIdentity()
            return
        }
        let result: IdentityRemovalContent = try await delete(.devicePass)
        guard result.identityRemoved else { throw TaleForkServiceError.invalidResponse }
        try await clearLocalIdentity()
    }

    func refreshMembershipStatus() async throws -> MembershipStatusContent {
        try await post(.membershipStatus, body: [:])
    }

    func hostedMembershipOffers() async throws -> [HostedMembershipOffer] {
        let collection: HostedMembershipOfferCollection = try await post(.membershipOffers, body: [:])
        let offers = collection.offers.filter(\.isDisplayable)
        guard !offers.isEmpty else {
            throw TaleForkServiceError.unavailable(String(localized: "membership.presentation.empty"))
        }
        return offers
    }

    func hostedMembershipPage(offerID: String, clientRequestID: String) async throws -> HostedMembershipPage {
        let configuration = try await refreshMembershipConfiguration()
        guard configuration.route == .hostedPage, !configuration.allowedHosts.isEmpty else {
            throw TaleForkServiceError.unavailable(String(localized: "membership.presentation.unavailable"))
        }
        let page: HostedMembershipPage = try await post(.membershipCheckout, body: [
            "offerID": .text(offerID),
            "installID": .text(try await InstallIdentityStore.shared.installationID()),
            "clientRequestID": .text(clientRequestID)
        ])
        guard page.isPendingAndUnexpired, configuration.accepts(page.payDetail) else {
            throw TaleForkServiceError.invalidResponse
        }
        return page
    }

    func refreshAppleContext() async {
        if let context: AppleMembershipContextContent = try? await post(.appleContext, body: [:]) {
            appleAccountToken = context.appAccountToken
            appleVerificationEnabled = context.enabled
        }
    }

    func deliverAppleTransaction(_ signedTransaction: String) async -> Bool {
        guard appleVerificationEnabled else { return false }
        let receipt: AppleTransactionReceiptContent? = try? await post(.appleTransactions,
            body: ["signedTransaction": .text(signedTransaction)])
        return receipt != nil
    }

    func bindSDKContextIfAvailable() async {
        guard AttributionRuntime.shouldCollect(), !accessPass.isEmpty,
              !audienceKey.isEmpty, !isBindingSDKContext else { return }
        isBindingSDKContext = true
        defer { isBindingSDKContext = false }
        let viewer = audienceKey
        let pass = accessPass
        let firebase = FirebaseAttribution.shared.appInstanceID
        let firebaseAppID = firebase == nil ? nil : FirebaseAttribution.shared.appID
        let sessionID = firebase == nil ? nil : await FirebaseAttribution.shared.sessionID()
        // Identity may be cleared/recovered while the SDK asynchronously reads its session.
        guard !Task.isCancelled, viewer == audienceKey, pass == accessPass,
              firebase == FirebaseAttribution.shared.appInstanceID,
              firebaseAppID == (firebase == nil ? nil : FirebaseAttribution.shared.appID) else { return }
        let meta = MetaAttribution.shared.context
        let anonymousID = meta.anonymousID.isEmpty ? nil : meta.anonymousID
        guard anonymousID != nil || firebase != nil else { return }
        let context = SDKContextReport(
            metaAnonymousID: anonymousID, firebaseAppInstanceID: firebase,
            metaAdvertiserTrackingEnabled: anonymousID != nil && meta.advertiserTrackingEnabled,
            metaApplicationTrackingEnabled: anonymousID != nil && meta.applicationTrackingEnabled,
            googleAnalyticsStorageGranted: firebase != nil,
            // No advertising consent has been granted in the current app.
            // ATT permission must not silently grant personalized-ad consent.
            googleAdUserDataGranted: false, googleAdPersonalizationGranted: false,
            appVersion: meta.appVersion, appBuild: meta.appBuild, osVersion: meta.osVersion,
            deviceModel: meta.deviceModel, locale: meta.locale, firebaseSessionID: sessionID,
            firebaseAppID: firebaseAppID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let payload = try? encoder.encode(context) else { return }
        guard payload != lastBoundSDKContext || viewer != lastBoundSDKContextAudience else { return }
        do {
            // Best-effort and independent of registration/payment. Do not use
            // post(), whose authentication recovery could recursively rebind.
            var request = URLRequest(url: baseURL.appendingPathComponent(ServiceRoute.sdkContext.rawValue))
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            request.httpBody = payload
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("talefork-ios-r2", forHTTPHeaderField: "X-TaleFork-Edition")
            request.setValue(pass, forHTTPHeaderField: "X-TaleFork-Pass")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard viewer == audienceKey, pass == accessPass,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            let envelope = try JSONDecoder().decode(MobileEnvelope<SDKContextReceipt>.self, from: data)
            guard envelope.outcome == "READY", envelope.content?.accepted == true else { return }
            lastBoundSDKContext = payload
            lastBoundSDKContextAudience = viewer
        } catch {
            // A later foreground activation retries without blocking App use.
        }
    }

    func clearLocalIdentity() async throws {
        try await sessionStore.clear()
        accessPass = ""
        audienceKey = ""
        appleAccountToken = nil
        appleVerificationEnabled = false
        resetMembershipConfiguration()
    }

    private func resetMembershipConfiguration() {
        hasLoadedMembershipConfiguration = false
        membershipScreenshotsAllowed = false
        membershipPresentationConfiguration = MembershipPresentationConfiguration(
            reviewModel: nil, showVip: nil, allowedHosts: [])
    }

    private func ensureSession(forceRecovery: Bool = false) async throws -> DevicePassContent {
        if let sessionTask { return try await sessionTask.value }
        if !forceRecovery, !accessPass.isEmpty, !audienceKey.isEmpty {
            return DevicePassContent(audienceKey: audienceKey, accessPass: accessPass)
        }
        let task = Task { @MainActor in
            if self.audienceKey.isEmpty, let stored = try await self.sessionStore.load() {
                self.audienceKey = stored.audienceKey
                self.accessPass = stored.accessPass
            }
            if !forceRecovery, !self.accessPass.isEmpty, !self.audienceKey.isEmpty {
                return DevicePassContent(audienceKey: self.audienceKey, accessPass: self.accessPass)
            }
            let restoring = forceRecovery || !self.audienceKey.isEmpty
                || InstallIdentityStore.shared.hasHistoricalInstallation
            do {
                return try await self.registerSession(restoring: restoring)
            } catch TaleForkServiceError.identityRemoved where restoring {
                // Only this explicit business response permits replacement.
                try await self.clearLocalIdentity()
                return try await self.registerSession(restoring: false)
            }
        }
        sessionTask = task
        defer { sessionTask = nil }
        return try await task.value
    }

    private func registerSession(restoring: Bool) async throws -> DevicePassContent {
        var body = try await devicePassRequest()
        body["sessionIntent"] = .text(restoring ? "RESTORE" : "CREATE")
        body["audienceKey"] = .text(audienceKey)
        let identity: DevicePassContent = try await post(.devicePass, body: body, requiresPass: false)
        guard !identity.audienceKey.isEmpty, !identity.accessPass.isEmpty else {
            throw TaleForkServiceError.invalidResponse
        }
        if restoring, !audienceKey.isEmpty, identity.audienceKey != audienceKey {
            throw TaleForkServiceError.invalidResponse
        }
        try await sessionStore.save(accessPass: identity.accessPass, audienceKey: identity.audienceKey)
        accessPass = identity.accessPass
        audienceKey = identity.audienceKey
        Task { await self.bindSDKContextIfAvailable() }
        return identity
    }

    @discardableResult
    func refreshMembershipConfiguration() async throws -> MembershipPresentationConfiguration {
        // Each paywall entry/foreground return needs a fresh server decision,
        // not a possibly older in-flight bootstrap manifest.
        let manifest: LaunchManifestContent = try await post(.launchManifest, body: launchRequest)
        try Task.checkCancellation()
        applyMembershipConfiguration(manifest)
        return membershipPresentationConfiguration
    }

    private func loadMembershipConfiguration() async throws -> LaunchManifestContent {
        if let manifestTask { return try await manifestTask.value }
        let task = Task { @MainActor in
            do {
                let manifest: LaunchManifestContent = try await self.post(.launchManifest, body: self.launchRequest)
                self.applyMembershipConfiguration(manifest)
                return manifest
            } catch {
                self.resetMembershipConfiguration()
                throw error
            }
        }
        manifestTask = task
        defer { manifestTask = nil }
        return try await task.value
    }

    private func applyMembershipConfiguration(_ manifest: LaunchManifestContent) {
        AttributionStore.shared.applyServerPromotionID(manifest.promotionID)
        membershipScreenshotsAllowed = manifest.vipScreenShot ?? false
        membershipPresentationConfiguration = MembershipPresentationConfiguration(
            reviewModel: manifest.reviewModel, showVip: manifest.showVip,
            allowedHosts: Set(manifest.allowedCheckoutHosts.map { $0.lowercased() }))
        hasLoadedMembershipConfiguration = true
    }

    private func post<Content: Decodable>(
        _ route: ServiceRoute,
        body: [String: JSONScalar],
        requiresPass: Bool = true,
        mayRecover: Bool = true
    ) async throws -> Content {
        #if DEBUG
        let started = Date()
        NSLog("[MembershipAPI] start %@ host=%@", route.rawValue, baseURL.host ?? "")
        defer { NSLog("[MembershipAPI] end %@ elapsed=%.2fs cancelled=%@", route.rawValue,
                      Date().timeIntervalSince(started), Task.isCancelled.description) }
        #endif
        if requiresPass { _ = try await ensureSession() }
        try Task.checkCancellation()
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if route == .membershipCheckout, case .text(let attempt) = body["clientRequestID"] {
            request.setValue(attempt, forHTTPHeaderField: "Idempotency-Key")
        }
        request.setValue("talefork-ios-r2", forHTTPHeaderField: "X-TaleFork-Edition")
        if requiresPass, !accessPass.isEmpty {
            request.setValue(accessPass, forHTTPHeaderField: "X-TaleFork-Pass")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw TaleForkServiceError.invalidResponse
        }
        if http.statusCode == 401 {
            guard requiresPass, mayRecover else { throw TaleForkServiceError.unauthorized }
            _ = try await ensureSession(forceRecovery: true)
            return try await post(route, body: body, requiresPass: requiresPass, mayRecover: false)
        }
        if http.statusCode == 409,
           let error = try? JSONDecoder().decode(MobileEnvelope<Content>.self, from: data),
           error.outcome == "IDENTITY_REMOVED" {
            throw TaleForkServiceError.identityRemoved
        }
        guard (200..<300).contains(http.statusCode) else { throw TaleForkServiceError.invalidResponse }
        guard let envelope = try? JSONDecoder().decode(MobileEnvelope<Content>.self, from: data) else {
            throw TaleForkServiceError.decoding
        }
        guard envelope.outcome == "READY" else { throw TaleForkServiceError.rejected(envelope.detail ?? "") }
        guard let content = envelope.content else { throw TaleForkServiceError.invalidResponse }
        return content
    }

    private func delete<Content: Decodable>(_ route: ServiceRoute) async throws -> Content {
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("talefork-ios-r2", forHTTPHeaderField: "X-TaleFork-Edition")
        request.setValue(accessPass, forHTTPHeaderField: "X-TaleFork-Pass")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TaleForkServiceError.invalidResponse
        }
        if http.statusCode == 401 { throw TaleForkServiceError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw TaleForkServiceError.invalidResponse }
        guard let envelope = try? JSONDecoder().decode(MobileEnvelope<Content>.self, from: data) else {
            throw TaleForkServiceError.decoding
        }
        guard envelope.outcome == "READY" else { throw TaleForkServiceError.rejected(envelope.detail ?? "") }
        guard let content = envelope.content else { throw TaleForkServiceError.invalidResponse }
        return content
    }

    private func devicePassRequest() async throws -> [String: JSONScalar] {
        let attribution = AttributionStore.shared.snapshot
        #if DEBUG
        // Synthetic acquisition evidence belongs only to explicit routing UI
        // fixtures, whose SDK collection is disabled. Ordinary Debug builds,
        // like Release, retain unknown/organic source without a real ad click.
        let isRoutingFixture = ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] != nil
        let isOrganicRoutingFixture = isRoutingFixture
            && ProcessInfo.processInfo.environment["TALEFORK_TEST_ORGANIC_ROUTING"] == "1"
        let attributionSource = isOrganicRoutingFixture ? "unknown"
            : (isRoutingFixture && attribution.source == .unknown ? "meta" : attribution.source.rawValue)
        let promotionID = isOrganicRoutingFixture ? "" : (attribution.promotionID ?? (isRoutingFixture ? "FB001" : ""))
        // UI-test copies can have a temporary bundle identifier. An explicit
        // fixture keeps their channel contract aligned with the installed app;
        // release builds always use the real bundle identifier below.
        let packageName = ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] != nil
            ? (ProcessInfo.processInfo.environment["TALEFORK_TEST_PACKAGE_NAME"] ?? Bundle.main.bundleIdentifier ?? "com.talefork.storypaths")
            : (Bundle.main.bundleIdentifier ?? "com.talefork.storypaths")
        #else
        let attributionSource = attribution.source.rawValue
        let promotionID = attribution.promotionID ?? ""
        let packageName = Bundle.main.bundleIdentifier ?? "com.talefork.storypaths"
        #endif
        return [
            "deviceSeed": .text(try await InstallIdentityStore.shared.installationID()),
            "releaseName": .text(releaseName),
            "releaseBuild": .text(releaseBuild),
            "languageTag": .text(Self.languageTag),
            "hardwareFamily": .text(UIDevice.current.model),
            "packageName": .text(packageName),
            "attributionSource": .text(attributionSource),
            "promotionId": .text(promotionID),
            "adId": .text(attribution.adID ?? ""),
            "adSetId": .text(attribution.adSetID ?? ""),
            "clickId": .text(attribution.clickID ?? "")
        ]
    }

    private var launchRequest: [String: JSONScalar] {
        let attribution = AttributionStore.shared.snapshot
        return [
            "releaseName": .text(releaseName),
            "releaseBuild": .text(releaseBuild),
            "attributionSource": .text(attribution.source.rawValue),
            "promotionId": .text(attribution.promotionID ?? "")
        ]
    }

    private var releaseName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var releaseBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private static var languageTag: String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh-Hant") { return "zh-HK" }
        if language.hasPrefix("zh-Hans") { return "zh" }
        if language.hasPrefix("ko") { return "ko" }
        if language.hasPrefix("id") { return "id" }
        if language.hasPrefix("ms") { return "ms" }
        if language.hasPrefix("fil") || language.hasPrefix("tl") { return "tl" }
        if language.hasPrefix("th") { return "th" }
        if language.hasPrefix("ja") { return "ja" }
        return "en"
    }
}

private struct SDKContextReceipt: Decodable {
    let accepted: Bool
}

private struct AppleMembershipContextContent: Decodable {
    let enabled: Bool
    let appAccountToken: UUID
}

private struct AppleTransactionReceiptContent: Decodable {
    let transactionID: String
}

@MainActor
@Observable
final class CatalogStore {
    private(set) var dramas: [Drama] = []
    private(set) var searchResults: [Drama] = []
    private(set) var currentUserID = ""
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var errorMessage: String?
    private(set) var searchErrorMessage: String?

    private let service: any CatalogServing
    private var hasLoaded = false
    private var searchRequestID = UUID()

    init(service: any CatalogServing = TaleForkService.shared) {
        self.service = service
    }

    var featured: Drama? { dramas.first }

    func drama(id: String) -> Drama? {
        dramas.first { $0.id == id }
    }

    func load(force: Bool = false) async {
        guard force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let bootstrap = try await service.bootstrap()
            guard !bootstrap.dramas.isEmpty else { throw TaleForkServiceError.invalidResponse }
            dramas = bootstrap.dramas
            currentUserID = bootstrap.userID
            hasLoaded = true
            #if DEBUG
            NSLog("[CatalogStore] Loaded %d dramas (%d with artwork)", dramas.count, dramas.filter { $0.coverURL != nil }.count)
            #endif
        } catch {
            #if DEBUG
            if let keychainError = error as? IdentityKeychainError {
                NSLog("[CatalogStore] Identity access failed: OSStatus %d", keychainError.status)
            } else {
                NSLog("[CatalogStore] Load failed: %@", error.localizedDescription)
            }
            #endif
            errorMessage = error.localizedDescription
            if dramas.isEmpty { searchResults = [] }
        }
    }

    func retry() async { await load(force: true) }

    @discardableResult
    func deleteAccount() async -> Bool {
        do {
            try await service.deleteAccount()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        currentUserID = ""
        dramas = []
        searchResults = []
        errorMessage = nil
        searchErrorMessage = nil
        hasLoaded = false
        searchRequestID = UUID()
        return true
    }

    func search(keyword: String) async {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestID = UUID()
        searchRequestID = requestID
        guard !value.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }
        isSearching = true
        searchErrorMessage = nil
        defer {
            if searchRequestID == requestID { isSearching = false }
        }
        do {
            let results = try await service.search(value)
            guard searchRequestID == requestID, !Task.isCancelled else { return }
            searchResults = results
        } catch {
            guard searchRequestID == requestID, !Task.isCancelled else { return }
            searchResults = dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(value)
            }
            searchErrorMessage = error.localizedDescription
        }
    }
}
