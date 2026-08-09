import Foundation

enum ValidationError: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct DramaValidator {
    @MainActor
    static func main() throws {
        let drama = DramaLibrary.beforeRainStops
        try require(DramaLibrary.dramas.count >= 3, "Catalog must contain at least three titles")
        try require(drama.episodes.count >= 6, "Playable drama must contain at least six episodes")
        try require(drama.endings.count >= 2, "Playable drama must contain at least two endings")

        var pending = [drama.entryEpisodeID]
        var reached = Set<String>()
        while let id = pending.popLast() {
            guard reached.insert(id).inserted, let episode = drama.episode(id: id) else { continue }
            if episode.ending == nil { try require(!episode.choices.isEmpty, "Episode \(id) has no ending or choice") }
            for choice in episode.choices {
                try require(drama.episode(id: choice.destinationEpisodeID) != nil, "Choice \(choice.id) points to missing episode")
                pending.append(choice.destinationEpisodeID)
            }
            let video = "TaleFork/Resources/Videos/\(episode.clipName).mp4"
            try require(FileManager.default.fileExists(atPath: video), "Missing video \(video)")
        }
        try require(reached == Set(drama.episodes.map(\.id)), "Some episodes are unreachable")

        let suite = "TaleForkValidation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(defaults: defaults)
        store.start(drama)
        let first = drama.episode(id: drama.entryEpisodeID)!
        store.watch(drama: drama, episodeID: first.id, position: 3.5)
        store.choose(first.choices[0], in: drama)
        store.toggleFavorite(drama)
        let restored = ProgressStore(defaults: defaults)
        try require(restored.run(for: drama) == store.run(for: drama), "Progress did not persist")
        try require(restored.isFavorite(drama), "Favorite did not persist")
        try require(restored.history.first?.dramaID == drama.id, "Watch history did not persist")
        try require(restored.run(for: drama).playbackSeconds[first.id] == 3.5, "Playback position did not persist")

        print("PASS catalog: \(DramaLibrary.dramas.count) titles")
        print("PASS graph: \(reached.count) reachable episodes, \(drama.endings.count) endings")
        print("PASS media: all playable clips exist")
        print("PASS persistence: progress, playback, history and favorites restored")
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ValidationError.failed(message) }
    }
}
