import AVFoundation
import SwiftUI
import XCTest
#if targetEnvironment(simulator)
import StoreKit
import StoreKitTest
#endif
@testable import TaleFork

@MainActor
final class AttributionSDKConfigurationTests: XCTestCase {
    func testSDKContextCannotClaimABusinessEventOrGrantAdvertisingConsent() throws {
        let context = SDKContextReport(metaAnonymousID: nil, firebaseAppInstanceID: "sdk-fixture-instance",
            metaAdvertiserTrackingEnabled: false, metaApplicationTrackingEnabled: false,
            googleAnalyticsStorageGranted: true, googleAdUserDataGranted: false,
            googleAdPersonalizationGranted: false, appVersion: "1.0", appBuild: "1",
            osVersion: "26.5", deviceModel: "iPhone", locale: "zh_HK", firebaseSessionID: 12345,
            firebaseAppID: "1:765585726405:ios:20ae4441a19fc5bb1cc9ac")
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as? [String: Any])
        XCTAssertEqual(fields["firebaseAppInstanceID"] as? String, "sdk-fixture-instance")
        XCTAssertEqual(fields["firebaseSessionID"] as? Int64, 12345)
        XCTAssertEqual(fields["firebaseAppID"] as? String, "1:765585726405:ios:20ae4441a19fc5bb1cc9ac")
        XCTAssertNil(fields["metaAnonymousID"])
        XCTAssertEqual(fields["googleAdUserDataGranted"] as? Bool, false)
        XCTAssertEqual(fields["googleAdPersonalizationGranted"] as? Bool, false)
        for forbidden in ["kind", "eventID", "eventTime", "value", "currency", "transactionID", "viewerId"] {
            XCTAssertNil(fields[forbidden])
        }
    }

    func testMissingFirebaseInitializationHasNoSyntheticInstanceID() async {
        // XCTest suppresses SDK initialization; no device seed or UUID fallback.
        XCTAssertFalse(FirebaseAttribution.shared.isConfigured)
        FirebaseAttribution.shared.recordScreen(name: "fixture", screenClass: "XCTest")
        XCTAssertFalse(FirebaseAttribution.shared.isConfigured)
        XCTAssertNil(FirebaseAttribution.shared.appInstanceID)
        XCTAssertNil(FirebaseAttribution.shared.appID)
        let sessionID = await FirebaseAttribution.shared.sessionID()
        XCTAssertNil(sessionID)
    }

    func testMetaConfigurationFailsClosedWithoutRealClientToken() {
        XCTAssertFalse(MetaAttribution.hasClientConfiguration([:]))
        XCTAssertFalse(MetaAttribution.hasClientConfiguration([
            "FacebookAppID": "2221984505012142", "FacebookClientToken": "  "
        ]))
        XCTAssertFalse(MetaAttribution.hasClientConfiguration([
            "FacebookAppID": "2221984505012142", "FacebookClientToken": "$(TALEFORK_META_CLIENT_TOKEN)"
        ]))
        XCTAssertFalse(MetaAttribution.hasClientConfiguration([
            "FacebookAppID": "other-app", "FacebookClientToken": "fixture-client-token"
        ]))
        XCTAssertTrue(MetaAttribution.hasClientConfiguration([
            "FacebookAppID": "2221984505012142", "FacebookClientToken": "fixture-client-token"
        ]))
    }

    func testBundledMetaConfigurationIsResolvedWithoutServerCredentials() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertTrue(MetaAttribution.hasClientConfiguration(info))
        let token = try XCTUnwrap(info["FacebookClientToken"] as? String)
        // A client token is public SDK configuration, not an app secret or CAPI token.
        XCTAssertEqual(token.count, 32)
        XCTAssertTrue(token.allSatisfy(\.isHexDigit))
        for forbidden in ["FacebookAppSecret", "MetaCAPIAccessToken", "TELEFOKR_META_ACCESS_TOKEN"] {
            XCTAssertNil(info[forbidden])
        }
        XCTAssertEqual(info["FacebookAutoLogAppEventsEnabled"] as? Bool, false)
        XCTAssertEqual(info["FacebookAdvertiserIDCollectionEnabled"] as? Bool, false)
    }

    func testFixtureRunsCannotBecomeProductionAdEvents() {
        XCTAssertTrue(AttributionRuntime.shouldCollect(environment: [:]))
        for environment in [
            ["TALEFORK_ANALYTICS_DISABLED": "1"],
            ["TALEFORK_OFFLINE_CATALOG": "1"],
            ["TALEFORK_UI_SCREEN": "membership"],
            ["XCTestConfigurationFilePath": "fixture.xctestconfiguration"],
            ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        ] {
            XCTAssertFalse(AttributionRuntime.shouldCollect(environment: environment))
        }
    }

    func testXCTestCannotStartMetaOrRequestTrackingAuthorization() async {
        MetaAttribution.shared.start()
        MetaAttribution.shared.activate()
        await MetaAttribution.shared.requestTrackingAuthorizationIfNeeded()
        XCTAssertFalse(MetaAttribution.shared.isConfigured)
        XCTAssertTrue(MetaAttribution.shared.context.anonymousID.isEmpty)
    }

    func testFirebaseConfigMatchesOnlyThisApp() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"))
        let data = try Data(contentsOf: url)
        let config = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(config["BUNDLE_ID"] as? String, Bundle.main.bundleIdentifier)
        XCTAssertEqual(config["PROJECT_ID"] as? String, "talefork-44656")
        XCTAssertEqual(config["GOOGLE_APP_ID"] as? String, "1:765585726405:ios:20ae4441a19fc5bb1cc9ac")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "FacebookAutoLogAppEventsEnabled") as? Bool, false)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "FacebookAdvertiserIDCollectionEnabled") as? Bool, false)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED") as? Bool, false)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "FirebaseAutomaticScreenReportingEnabled") as? Bool, false)
    }
}

final class DramaModelTests: XCTestCase {
    func testVIPAccessStartsAtEpisodeEleven() {
        XCTAssertFalse(MembershipAccess.requiresSubscription(forEpisodeNumber: 1))
        XCTAssertFalse(MembershipAccess.requiresSubscription(forEpisodeNumber: 10))
        XCTAssertTrue(MembershipAccess.requiresSubscription(forEpisodeNumber: 11))
        XCTAssertTrue(MembershipAccess.requiresSubscription(forEpisodeNumber: 59))
    }

    func testHorizontalMarginsCoverSupportedIPhoneWidths() {
        let supportedWidths: [CGFloat] = [320, 375, 390, 402, 430, 440]
        let margins = supportedWidths.map(TaleForkTheme.horizontalMargin(for:))

        XCTAssertTrue(margins.allSatisfy { (16...28).contains($0) })
        XCTAssertEqual(margins, margins.sorted())
        XCTAssertEqual(TaleForkTheme.horizontalMargin(for: 320), 16.64, accuracy: 0.001)
        XCTAssertEqual(TaleForkTheme.horizontalMargin(for: 440), 22.88, accuracy: 0.001)
    }

    func testFixtureContainsUniqueOrderedEpisodes() throws {
        let drama = makeTestDrama()
        XCTAssertEqual(drama.availability, .available)
        XCTAssertEqual(drama.episodes.count, 3)
        XCTAssertNotNil(drama.episode(id: drama.entryEpisodeID))

        let ids = drama.episodes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(drama.episodes.map(\.number), [1, 2, 3])
        XCTAssertTrue(drama.episodes.allSatisfy { $0.videoURL != nil })
        XCTAssertEqual(
            drama.episodes.compactMap(\.videoURL?.path),
            [
                "/tale-assets/stories/test-drama/reels/1/playback.mp4",
                "/tale-assets/stories/test-drama/reels/2/playback.mp4",
                "/tale-assets/stories/test-drama/reels/3/playback.mp4"
            ]
        )
    }

    func testLocalizationKeySetsMatch() throws {
        var baseline: Set<String>?
        for language in ["en", "ja", "zh-Hans", "zh-Hant"] {
            let lproj = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let path = URL(fileURLWithPath: lproj).appendingPathComponent("Localizable.strings").path
            let dictionary = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            let keys = Set(dictionary.keys)
            XCTAssertGreaterThan(keys.count, 70)
            if let baseline { XCTAssertEqual(keys, baseline) } else { baseline = keys }
        }
    }
}

final class MembershipPreviewSourceTests: XCTestCase {
    func testRetentionPreviewUsesHTTPSAndFreeEpisodeOnly() throws {
        let drama = makeTestDrama()
        XCTAssertEqual(MembershipPreviewSource.url(for: drama), try XCTUnwrap(drama.episodes.first?.videoURL))
        let episodes = [
            DramaEpisode(id: "locked", number: 11, title: .server("Locked"), sceneCaption: .server(""), clipName: "", videoURL: URL(string: "https://example.test/locked.mp4"), durationSeconds: 10),
            DramaEpisode(id: "fixture", number: 1, title: .server("Fixture"), sceneCaption: .server(""), clipName: "", videoURL: URL(string: "talefork-preview://fake"), durationSeconds: 10)
        ]
        let unavailable = Drama(id: drama.id, title: drama.title, subtitle: drama.subtitle, storySummary: drama.storySummary,
                                posterImageName: drama.posterImageName, coverURL: drama.coverURL, accentHex: drama.accentHex,
                                availability: drama.availability, entryEpisodeID: episodes[0].id, episodes: episodes)
        XCTAssertNil(MembershipPreviewSource.url(for: unavailable))
    }
}

@MainActor
final class MembershipConfigurationTests: XCTestCase {
    func testPartialAppleCatalogStillNeedsRefresh() {
        XCTAssertFalse(MembershipAccess.hasAllProducts(in: []))
        XCTAssertFalse(MembershipAccess.hasAllProducts(in: [MembershipAccess.weeklyProductID]))
        XCTAssertFalse(MembershipAccess.hasAllProducts(in: [MembershipAccess.weeklyProductID, MembershipAccess.monthlyProductID]))
        XCTAssertTrue(MembershipAccess.hasAllProducts(in: Array(MembershipAccess.productIDs.reversed())))
        XCTAssertFalse(MembershipAccess.hasAllProducts(in: [MembershipAccess.weeklyProductID, MembershipAccess.weeklyProductID, "unrelated.product"]))
    }

    func testAppleConfigurationIncludesWeekMonthAndQuarter() throws {
        let configurationURL = try XCTUnwrap(
            Bundle(for: MembershipConfigurationTests.self).url(forResource: "TaleFork", withExtension: "storekit")
        )
        let configurationData = try Data(contentsOf: configurationURL)
        let configuration = try XCTUnwrap(
            JSONSerialization.jsonObject(with: configurationData) as? [String: Any]
        )
        let groups = try XCTUnwrap(configuration["subscriptionGroups"] as? [[String: Any]])
        let subscriptions = try XCTUnwrap(groups.first?["subscriptions"] as? [[String: Any]])
        let weekly = try XCTUnwrap(subscriptions.first)

        XCTAssertEqual(weekly["productID"] as? String, "com.talefork.storypaths.vip.weekly")
        XCTAssertEqual(weekly["displayPrice"] as? String, "19.99")
        XCTAssertEqual(weekly["recurringSubscriptionPeriod"] as? String, "P1W")
        let settings = try XCTUnwrap(configuration["settings"] as? [String: Any])
        XCTAssertEqual(settings["_locale"] as? String, "en_US")
        XCTAssertEqual(settings["_storefront"] as? String, "USA")
        XCTAssertEqual(subscriptions.count, 3)
        XCTAssertEqual(weekly["productID"] as? String, MembershipAccess.weeklyProductID)
        XCTAssertEqual(subscriptions.map { $0["productID"] as? String }, MembershipAccess.productIDs)
        XCTAssertEqual(subscriptions.map { $0["recurringSubscriptionPeriod"] as? String }, ["P1W", "P1M", "P3M"])
        XCTAssertEqual(subscriptions.map { $0["displayPrice"] as? String }, ["19.99", "29.9", "49.9"])
        XCTAssertTrue(subscriptions.allSatisfy { $0["subscriptionGroupID"] as? String == groups.first?["id"] as? String })
        XCTAssertTrue(subscriptions.allSatisfy { $0["type"] as? String == "RecurringSubscription" })
    }

    func testAllConfiguredApplePlansGrantAccessAndFlowStartsAtThreeMinutes() {
        for id in MembershipAccess.productIDs { XCTAssertTrue(MembershipAccess.isMembershipProduct(id)) }
        XCTAssertFalse(MembershipAccess.isMembershipProduct("unrelated.product"))
        XCTAssertTrue(MembershipAccess.isMembershipProduct("com.talefork.storypaths.vip.monthly"))
        XCTAssertTrue(MembershipAccess.isMembershipProduct("com.talefork.storypaths.vip.quarterly"))
        XCTAssertEqual(MembershipAccess.periodKey(for: MembershipAccess.monthlyProductID), "membership.apple.monthly")
        XCTAssertEqual(MembershipAccess.periodKey(for: MembershipAccess.quarterlyProductID), "membership.apple.quarterly")
        let store = MembershipStore()
        store.beginPaywallFlow()
        let original = store.promotionDeadline
        XCTAssertEqual(store.remainingPromotionSeconds, 180)
        store.beginPaywallFlow()
        XCTAssertEqual(store.promotionDeadline, original)
        store.endPaywallFlow()
    }
}

#if targetEnvironment(simulator)
@MainActor
final class MembershipStoreKitRuntimeTests: XCTestCase {
    /// Verifies the actual StoreKit loading path, not just the JSON contents.
    /// Local testing only; never purchases or clears transactions.
    func testLocalStoreKitReturnsAllConfiguredMemberships() async throws {
        let configurationURL = try XCTUnwrap(
            Bundle(for: MembershipStoreKitRuntimeTests.self).url(forResource: "TaleFork", withExtension: "storekit")
        )
        let session = try SKTestSession(contentsOf: configurationURL)
        let products = try await Product.products(for: MembershipAccess.productIDs)
        XCTAssertEqual(Set(products.map(\.id)), Set(MembershipAccess.productIDs))
        XCTAssertTrue(products.allSatisfy { $0.type == .autoRenewable })
        let expectedPrices: [String: Decimal] = [
            MembershipAccess.weeklyProductID: Decimal(string: "19.99")!,
            MembershipAccess.monthlyProductID: Decimal(string: "29.90")!,
            MembershipAccess.quarterlyProductID: Decimal(string: "49.90")!
        ]
        for product in products {
            XCTAssertEqual(product.price, expectedPrices[product.id])
        }
        withExtendedLifetime(session) {}
    }
}
#endif

final class MembershipClientContractTests: XCTestCase {
    func testClientUsesGenericServerOrchestrationAndAppleEndpoints() {
        let expected: Set<String> = [
            "tale-gateway/v2/heartbeat", "tale-gateway/v2/identity/device-pass",
            "tale-gateway/v2/launch/manifest", "tale-gateway/v2/screenings/lineup",
            "tale-gateway/v2/screenings/search", "tale-gateway/v2/membership/status",
            "tale-gateway/v2/membership/offers", "tale-gateway/v2/membership/checkout",
            "tale-gateway/v2/membership/apple/context", "tale-gateway/v2/membership/apple/transactions",
            "tale-gateway/v2/analytics/meta-events"
        ]
        XCTAssertEqual(Set(ServiceRoute.allCases.map(\.rawValue)), expected)
    }

    func testExplicitReviewFlagWinsAndMissingConfigurationFailsClosed() {
        XCTAssertEqual(MembershipPresentationConfiguration(reviewModel: true, showVip: true, allowedHosts: []).route, .appStore)
        XCTAssertEqual(MembershipPresentationConfiguration(reviewModel: false, showVip: false, allowedHosts: []).route, .hostedPage)
        XCTAssertEqual(MembershipPresentationConfiguration(reviewModel: nil, showVip: true, allowedHosts: []).route, .hostedPage)
        XCTAssertEqual(MembershipPresentationConfiguration(reviewModel: nil, showVip: false, allowedHosts: []).route, .appStore)
        XCTAssertEqual(MembershipPresentationConfiguration(reviewModel: nil, showVip: nil, allowedHosts: []).route, .appStore)
    }

    func testReturnedPageMustBeHTTPSOnServerAllowedHost() throws {
        let config = MembershipPresentationConfiguration(reviewModel: false, showVip: true, allowedHosts: ["checkout.example.test"])
        XCTAssertTrue(config.accepts(try XCTUnwrap(URL(string: "https://checkout.example.test/page?id=123"))))
        for raw in ["http://checkout.example.test/page", "https://other.example.test/page",
                    "https://user:pass@checkout.example.test/page", "https://checkout.example.test:8443/page"] {
            XCTAssertFalse(config.accepts(try XCTUnwrap(URL(string: raw))))
        }
    }

    func testOfferDescriptionAndPurchaseDetailsUseSeparateBackendFields() throws {
        let data = Data(#"{"offers":[{"id":"2019","title":"訂閱會員","displayPrice":"HK$1.00","default":true,"description":"internal-name","vipDesc":"原價 788","trailDesc":"體驗及續訂須知"}]}"#.utf8)
        let response = try JSONDecoder().decode(HostedMembershipOfferCollection.self, from: data)
        let offer = try XCTUnwrap(response.offers.first)
        XCTAssertTrue(offer.isDisplayable)
        XCTAssertTrue(offer.isDefault)
        XCTAssertEqual(offer.vipDesc, "原價 788")
        XCTAssertEqual(offer.trailDesc, "體驗及續訂須知")
        XCTAssertEqual(offer.displayPrice, "HK$1.00")
    }
}

@MainActor
final class MembershipPaywallLoadingTests: XCTestCase {
    private func snapshot(review: Bool) -> MembershipPresentationSnapshot {
        .init(configuration: .init(reviewModel: review, showVip: !review, allowedHosts: []), offers: [])
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(condition())
    }

    func testOnOffOnReloadReplacesRouteInsteadOfKeepingAppleCache() async throws {
        let loader = MembershipPaywallLoader()
        for review in [true, false, true, false] {
            loader.load { self.snapshot(review: review) }
            try await waitUntil { !loader.isLoading }
            XCTAssertNil(loader.errorMessage)
            XCTAssertEqual(loader.snapshot?.configuration.route, review ? .appStore : .hostedPage)
        }
        loader.cancel()
    }

    func testTimeoutEndsSpinnerEvenIfFetchIgnoresCancellation() async throws {
        let loader = MembershipPaywallLoader()
        var continuation: CheckedContinuation<MembershipPresentationSnapshot, Never>?
        loader.load(timeout: .milliseconds(30)) {
            await withCheckedContinuation { continuation = $0 }
        }
        try await waitUntil { continuation != nil }
        try await waitUntil { !loader.isLoading }
        XCTAssertNotNil(loader.errorMessage)
        XCTAssertNil(loader.snapshot)
        continuation?.resume(returning: snapshot(review: false))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(loader.snapshot, "A timed-out response must not replace the error state")
        loader.cancel()
    }

    func testRetryIgnoresPreviousLateResponse() async throws {
        let loader = MembershipPaywallLoader()
        var continuation: CheckedContinuation<MembershipPresentationSnapshot, Never>?
        loader.load { await withCheckedContinuation { continuation = $0 } }
        try await waitUntil { continuation != nil }
        loader.load { self.snapshot(review: false) }
        try await waitUntil { !loader.isLoading }
        continuation?.resume(returning: snapshot(review: true))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(loader.snapshot?.configuration.route, .hostedPage)
        XCTAssertNil(loader.errorMessage)
        loader.cancel()
    }

    func testFailureCanBeRetriedWithoutFallingBackToApple() async throws {
        let loader = MembershipPaywallLoader()
        loader.load { throw URLError(.cannotConnectToHost) }
        try await waitUntil { !loader.isLoading }
        XCTAssertNotNil(loader.errorMessage)
        XCTAssertNil(loader.snapshot)
        loader.load { self.snapshot(review: false) }
        try await waitUntil { !loader.isLoading }
        XCTAssertNil(loader.errorMessage)
        XCTAssertEqual(loader.snapshot?.configuration.route, .hostedPage)
        loader.cancel()
    }
}

@MainActor
final class LiveServiceTests: XCTestCase {
    func testLiveCatalogAndFirstVideoAreReachable() async throws {
        guard ProcessInfo.processInfo.environment["TALEFORK_RUN_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Live catalog, visitor registration, and playback checks require explicit opt-in")
        }

        let catalog = CatalogStore()
        await catalog.load(force: true)

        XCTAssertNil(catalog.errorMessage)
        XCTAssertFalse(catalog.currentUserID.isEmpty, "Visitor registration must return a stable user ID")
        let drama = try XCTUnwrap(catalog.dramas.first)
        XCTAssertGreaterThan(drama.episodes.count, 1)
        let videoURL = try XCTUnwrap(drama.episodes.first?.videoURL)

        var request = URLRequest(url: videoURL)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertTrue([200, 206].contains(http.statusCode))
        XCTAssertFalse(data.isEmpty)

        let asset = AVURLAsset(url: videoURL)
        let isPlayable = try await asset.load(.isPlayable)
        XCTAssertTrue(isPlayable)
        let duration = try await asset.load(.duration).seconds
        XCTAssertTrue(duration.isFinite)
        XCTAssertGreaterThan(duration, 1)

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .moviePlayback)
        try audioSession.setActive(true)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false

        for _ in 0..<30 where item.status == .unknown {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertEqual(item.status, .readyToPlay, item.error?.localizedDescription ?? "Player item did not become ready")
        player.play()
        for _ in 0..<30 where player.currentTime().seconds <= 0 {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertGreaterThan(player.currentTime().seconds, 0)
        player.pause()
    }
}

@MainActor
final class CatalogStoreTests: XCTestCase {
    func testFailedRefreshKeepsPreviouslyLoadedCatalog() async {
        let drama = makeTestDrama(id: "kept", title: "Kept Drama")
        let service = FakeCatalogService(
            bootstrapResults: [
                .success(CatalogBootstrap(userID: "viewer", dramas: [drama])),
                .failure(FakeServiceError.unavailable)
            ]
        )
        let catalog = CatalogStore(service: service)

        await catalog.load(force: true)
        XCTAssertEqual(catalog.dramas.map(\.id), ["kept"])
        XCTAssertNil(catalog.errorMessage)

        await catalog.retry()
        XCTAssertEqual(catalog.dramas.map(\.id), ["kept"])
        XCTAssertNotNil(catalog.errorMessage)
    }

    func testCancelledSearchCannotReplaceNewerResults() async {
        let slowDrama = makeTestDrama(id: "slow", title: "Slow")
        let fastDrama = makeTestDrama(id: "fast", title: "Fast")
        let service = FakeCatalogService(
            bootstrapResults: [.success(CatalogBootstrap(userID: "viewer", dramas: [slowDrama, fastDrama]))],
            searchHandler: { keyword in
                if keyword == "slow" {
                    try? await Task.sleep(for: .milliseconds(250))
                    return [slowDrama]
                }
                return [fastDrama]
            }
        )
        let catalog = CatalogStore(service: service)
        await catalog.load(force: true)

        let staleSearch = Task { await catalog.search(keyword: "slow") }
        try? await Task.sleep(for: .milliseconds(30))
        staleSearch.cancel()
        await catalog.search(keyword: "fast")
        await staleSearch.value

        XCTAssertEqual(catalog.searchResults.map(\.id), ["fast"])
        XCTAssertNil(catalog.searchErrorMessage)
        XCTAssertFalse(catalog.isSearching)
    }
}

#if targetEnvironment(simulator)
final class SimulatorIdentityKeychainTests: XCTestCase {
    /// Real SecItem access catches missing simulator entitlements (-34018),
    /// which otherwise prevents the live catalog from making any request.
    func testAdHocSimulatorCanReadAndUpdateItsOwnKeychain() async throws {
        let keychain = IdentityKeychain(service: "com.talefork.storypaths.tests.\(UUID().uuidString)")
        let account = "carousel-regression"
        do {
            let missing = try await keychain.read(account)
            XCTAssertNil(missing)
            let initial = Data("non-secret-test-fixture".utf8)
            try await keychain.write(initial, account: account)
            let stored = try await keychain.read(account)
            XCTAssertEqual(stored, initial)
            let updated = Data("updated-test-fixture".utf8)
            try await keychain.write(updated, account: account)
            let replacement = try await keychain.read(account)
            XCTAssertEqual(replacement, updated)
            try await keychain.delete(account)
            let removed = try await keychain.read(account)
            XCTAssertNil(removed)
        } catch {
            // Only this test's UUID-scoped fixture is eligible for cleanup.
            try? await keychain.delete(account)
            throw error
        }
    }
}
#endif

@MainActor
final class ProgressStoreTests: XCTestCase {
    func testProgressFavoritesAndPersistence() throws {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let drama = makeTestDrama()
        let episode = drama.episodes[1]
        let store = ProgressStore(defaults: defaults)

        store.start(drama)
        store.selectEpisode(drama: drama, episodeID: episode.id)
        store.watch(drama: drama, episodeID: episode.id, position: 3.5)
        store.toggleFavorite(drama)

        XCTAssertEqual(store.run(for: drama).currentEpisodeID, episode.id)
        XCTAssertTrue(store.isFavorite(drama))
        XCTAssertEqual(store.history.first?.dramaID, drama.id)
        XCTAssertEqual(store.run(for: drama).playbackSeconds[episode.id], 3.5)
        XCTAssertTrue(store.run(for: drama).watchedEpisodeIDs.contains(episode.id))

        let restored = ProgressStore(defaults: defaults)
        XCTAssertEqual(restored.run(for: drama), store.run(for: drama))
        XCTAssertTrue(restored.isFavorite(drama))
    }

    func testSelectingEpisodeDoesNotCountAsWatchedUntilPlaybackThreshold() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let drama = makeTestDrama()
        let episode = drama.episodes[2]
        let store = ProgressStore(defaults: defaults)

        store.selectEpisode(drama: drama, episodeID: episode.id)
        XCTAssertFalse(store.run(for: drama).watchedEpisodeIDs.contains(episode.id))

        store.watch(drama: drama, episodeID: episode.id, position: 2.9)
        XCTAssertFalse(store.run(for: drama).watchedEpisodeIDs.contains(episode.id))

        store.watch(drama: drama, episodeID: episode.id, position: 3)
        XCTAssertTrue(store.run(for: drama).watchedEpisodeIDs.contains(episode.id))
    }

    func testSceneMarkPersistsAndRestoresItsExactPlaybackPosition() throws {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let drama = makeTestDrama()
        let episode = drama.episodes[1]
        let store = ProgressStore(defaults: defaults)

        let mark = store.addSceneMark(
            drama: drama,
            episode: episode,
            position: 12.5,
            kind: .clue,
            note: "  Watch the doorway  "
        )

        let restored = ProgressStore(defaults: defaults)
        let restoredMark = try XCTUnwrap(restored.sceneMarks.first)
        XCTAssertEqual(restoredMark, mark)
        XCTAssertEqual(restoredMark.note, "Watch the doorway")

        restored.preparePlayback(for: restoredMark, in: drama)
        let run = restored.run(for: drama)
        XCTAssertEqual(run.currentEpisodeID, episode.id)
        XCTAssertEqual(run.playbackSeconds[episode.id], 12.5)
    }

    func testDeletingLocalAccountRemovesIdentityStateAndPersistence() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let drama = makeTestDrama()
        let store = ProgressStore(defaults: defaults)

        store.hasCompletedOnboarding = true
        store.watch(drama: drama, episodeID: drama.entryEpisodeID, position: 8)
        store.toggleFavorite(drama)
        store.addSceneMark(
            drama: drama,
            episode: drama.episodes[0],
            position: 8,
            kind: .turningPoint,
            note: "Remove with local account"
        )
        store.deleteLocalAccount()

        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertTrue(store.runs.isEmpty)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertTrue(store.favoriteDramaIDs.isEmpty)
        XCTAssertTrue(store.sceneMarks.isEmpty)

        let restored = ProgressStore(defaults: defaults)
        XCTAssertFalse(restored.hasCompletedOnboarding)
        XCTAssertTrue(restored.runs.isEmpty)
        XCTAssertTrue(restored.sceneMarks.isEmpty)
    }

    private func makeDefaults() -> (String, UserDefaults) {
        let suite = "TaleForkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (suite, defaults)
    }
}

@MainActor
private final class FakeCatalogService: CatalogServing {
    private var bootstrapResults: [Result<CatalogBootstrap, Error>]
    private let searchHandler: (String) async throws -> [Drama]

    init(
        bootstrapResults: [Result<CatalogBootstrap, Error>],
        searchHandler: @escaping (String) async throws -> [Drama] = { _ in [] }
    ) {
        self.bootstrapResults = bootstrapResults
        self.searchHandler = searchHandler
    }

    func bootstrap() async throws -> CatalogBootstrap {
        guard !bootstrapResults.isEmpty else { throw FakeServiceError.unavailable }
        return try bootstrapResults.removeFirst().get()
    }

    func search(_ keyword: String) async throws -> [Drama] {
        try await searchHandler(keyword)
    }

    func deleteAccount() async throws {}

    func clearLocalIdentity() async throws {}
}

private enum FakeServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? { "Service unavailable" }
}

private func makeTestDrama(id: String = "test-drama", title: String = "Test Drama") -> Drama {
    let episodes = (1...3).map { number in
        DramaEpisode(
            id: "\(id)-\(number)",
            number: number,
            title: .server("Episode \(number)"),
            sceneCaption: .server("Test caption"),
            clipName: "",
            videoURL: URL(string: "https://example.com/tale-assets/stories/\(id)/reels/\(number)/playback.mp4"),
            durationSeconds: 30
        )
    }
    return Drama(
        id: id,
        title: .server(title),
        subtitle: .server("Test Subtitle"),
        storySummary: .server("Test Synopsis"),
        posterImageName: "",
        coverURL: URL(string: "https://example.com/cover.png"),
        accentHex: "E6A84C",
        availability: .available,
        entryEpisodeID: episodes[0].id,
        episodes: episodes
    )
}
