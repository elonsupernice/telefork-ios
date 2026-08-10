import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {
    private(set) var runs: [String: DramaRun] = [:]
    private(set) var favoriteDramaIDs: Set<String> = []
    private(set) var history: [WatchHistoryEntry] = []
    var preferences = AppPreferences() { didSet { persist() } }
    var hasCompletedOnboarding = false { didSet { persist() } }

    private let defaults: UserDefaults
    private let storageKey = "talefork.drama-state.v3"
    private var isRestoring = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
#if DEBUG
        if ProcessInfo.processInfo.environment["TALEFORK_UI_PREVIEW"] == "1" { hasCompletedOnboarding = true }
#endif
    }

    func run(for drama: Drama) -> DramaRun { runs[drama.id] ?? DramaRun(drama: drama) }

    func start(_ drama: Drama) {
        guard drama.availability == .available else { return }
        if runs[drama.id] == nil { runs[drama.id] = DramaRun(drama: drama) }
        recordWatch(drama: drama, episodeID: run(for: drama).currentEpisodeID)
    }

    func selectEpisode(drama: Drama, episodeID: String) {
        guard drama.episode(id: episodeID) != nil else { return }
        var run = run(for: drama)
        run.watch(
            episodeID: episodeID,
            position: run.playbackSeconds[episodeID] ?? 0,
            markWatched: false
        )
        runs[drama.id] = run
        recordWatch(drama: drama, episodeID: episodeID)
    }

    func watch(drama: Drama, episodeID: String, position: Double = 0, completed: Bool = false) {
        guard drama.episode(id: episodeID) != nil else { return }
        var run = run(for: drama)
        run.watch(episodeID: episodeID, position: position, markWatched: completed || position >= 3)
        runs[drama.id] = run
        recordWatch(drama: drama, episodeID: episodeID)
    }

    func toggleFavorite(_ drama: Drama) {
        if favoriteDramaIDs.contains(drama.id) { favoriteDramaIDs.remove(drama.id) }
        else { favoriteDramaIDs.insert(drama.id) }
        persist()
    }

    func isFavorite(_ drama: Drama) -> Bool { favoriteDramaIDs.contains(drama.id) }

    func resetAllProgress() {
        runs = [:]
        favoriteDramaIDs = []
        history = []
        persist()
    }

    func deleteLocalAccount() {
        isRestoring = true
        runs = [:]
        favoriteDramaIDs = []
        history = []
        preferences = AppPreferences()
        hasCompletedOnboarding = false
        isRestoring = false
        defaults.removeObject(forKey: storageKey)
    }

    private func recordWatch(drama: Drama, episodeID: String) {
        let entry = WatchHistoryEntry(id: drama.id, dramaID: drama.id, episodeID: episodeID, watchedAt: .now)
        history.removeAll { $0.dramaID == drama.id }
        history.insert(entry, at: 0)
        persist()
    }

    private func restore() {
        guard let data = defaults.data(forKey: storageKey), let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        isRestoring = true
        runs = state.runs
        favoriteDramaIDs = state.favoriteDramaIDs
        history = state.history
        preferences = state.preferences
        hasCompletedOnboarding = state.hasCompletedOnboarding
        isRestoring = false
    }

    private func persist() {
        guard !isRestoring else { return }
        let state = PersistedState(runs: runs, favoriteDramaIDs: favoriteDramaIDs, history: history, preferences: preferences, hasCompletedOnboarding: hasCompletedOnboarding)
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: storageKey) }
    }
}

private struct PersistedState: Codable {
    let runs: [String: DramaRun]
    let favoriteDramaIDs: Set<String>
    let history: [WatchHistoryEntry]
    let preferences: AppPreferences
    let hasCompletedOnboarding: Bool
}
