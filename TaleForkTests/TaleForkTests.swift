import AVFoundation
import XCTest
@testable import TaleFork

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

@MainActor
final class MembershipConfigurationTests: XCTestCase {
    func testWeeklySubscriptionConfigurationContract() throws {
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
        XCTAssertEqual(weekly["displayPrice"] as? String, "9.9")
        XCTAssertEqual(weekly["recurringSubscriptionPeriod"] as? String, "P1W")
        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(weekly["productID"] as? String, MembershipAccess.weeklyProductID)
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

    func clearLocalIdentity() {}
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
