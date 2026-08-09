import AVFoundation
import XCTest
@testable import TaleFork

final class DramaLibraryTests: XCTestCase {
    func testCatalogContainsPlayableInteractiveShortDrama() throws {
        XCTAssertGreaterThanOrEqual(DramaLibrary.dramas.count, 3)
        let drama = DramaLibrary.beforeRainStops
        XCTAssertEqual(drama.availability, .available)
        XCTAssertGreaterThanOrEqual(drama.episodes.count, 6)
        XCTAssertGreaterThanOrEqual(drama.endings.count, 2)
        XCTAssertNotNil(drama.episode(id: drama.entryEpisodeID))

        let ids = drama.episodes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for episode in drama.episodes {
            if episode.ending == nil { XCTAssertFalse(episode.choices.isEmpty) }
            for choice in episode.choices { XCTAssertNotNil(drama.episode(id: choice.destinationEpisodeID)) }
            XCTAssertNotNil(Bundle.main.url(forResource: episode.clipName, withExtension: "mp4"), "Missing video \(episode.clipName)")
        }
        XCTAssertNotNil(Bundle.main.url(forResource: drama.posterImageName, withExtension: nil))
    }

    func testEveryPlayableEpisodeIsReachable() {
        let drama = DramaLibrary.beforeRainStops
        var pending = [drama.entryEpisodeID]
        var reached = Set<String>()
        while let id = pending.popLast() {
            guard reached.insert(id).inserted, let episode = drama.episode(id: id) else { continue }
            pending.append(contentsOf: episode.choices.map(\.destinationEpisodeID))
        }
        XCTAssertEqual(reached, Set(drama.episodes.map(\.id)))
    }

    func testLocalizationKeySetsMatch() throws {
        var baseline: Set<String>?
        for language in ["en", "ja", "zh-Hant"] {
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
final class LiveServiceTests: XCTestCase {
    func testLiveCatalogAndFirstVideoAreReachable() async throws {
        let catalog = CatalogStore()
        await catalog.load(force: true)

        XCTAssertFalse(catalog.usesOfflineFallback, catalog.errorMessage ?? "Unexpected offline fallback")
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
final class ProgressStoreTests: XCTestCase {
    func testChoiceProgressFavoritesAndPersistence() throws {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let drama = DramaLibrary.beforeRainStops
        let entry = try XCTUnwrap(drama.episode(id: drama.entryEpisodeID))
        let choice = try XCTUnwrap(entry.choices.first)
        let store = ProgressStore(defaults: defaults)

        store.start(drama)
        store.watch(drama: drama, episodeID: entry.id, position: 3.5)
        store.choose(choice, in: drama)
        store.toggleFavorite(drama)

        XCTAssertEqual(store.run(for: drama).currentEpisodeID, choice.destinationEpisodeID)
        XCTAssertTrue(store.isFavorite(drama))
        XCTAssertEqual(store.history.first?.dramaID, drama.id)
        XCTAssertEqual(store.run(for: drama).playbackSeconds[entry.id], 3.5)

        let restored = ProgressStore(defaults: defaults)
        XCTAssertEqual(restored.run(for: drama), store.run(for: drama))
        XCTAssertTrue(restored.isFavorite(drama))
    }

    func testRestartKeepsUnlockedEndings() throws {
        let drama = DramaLibrary.beforeRainStops
        var run = DramaRun(drama: drama)
        var safety = 0
        while drama.episode(id: run.currentEpisodeID)?.ending == nil, safety < 20 {
            let episode = try XCTUnwrap(drama.episode(id: run.currentEpisodeID))
            run.choose(try XCTUnwrap(episode.choices.first), in: drama)
            safety += 1
        }
        XCTAssertFalse(run.completedEndingIDs.isEmpty)
        let endings = run.completedEndingIDs
        run.restart(with: drama)
        XCTAssertEqual(run.currentEpisodeID, drama.entryEpisodeID)
        XCTAssertTrue(run.watchedEpisodeIDs.isEmpty)
        XCTAssertEqual(run.completedEndingIDs, endings)
    }

    private func makeDefaults() -> (String, UserDefaults) {
        let suite = "TaleForkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (suite, defaults)
    }
}
