import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {
    private(set) var runs: [String: DramaRun] = [:]
    private(set) var favoriteDramaIDs: Set<String> = []
    private(set) var history: [WatchHistoryEntry] = []
    private(set) var sceneMarks: [SceneMark] = []
    var preferences = AppPreferences() { didSet { persist() } }
    var hasCompletedOnboarding = false { didSet { persist() } }

    private let defaults: UserDefaults
    private static let storageKey = "talefork.drama-state.v3"
    private var isRestoring = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
#if DEBUG
        if ProcessInfo.processInfo.environment["TALEFORK_UI_PREVIEW"] == "1" { hasCompletedOnboarding = true }
#endif
    }

#if DEBUG
    static func clearStoredStateForTesting(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
#endif

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

    @discardableResult
    func addSceneMark(
        drama: Drama,
        episode: DramaEpisode,
        position: Double,
        kind: SceneMarkKind,
        note: String
    ) -> SceneMark {
        let normalizedNote = String(
            note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)
        )
        let mark = SceneMark(
            dramaID: drama.id,
            dramaTitle: drama.title.resolved,
            episodeID: episode.id,
            episodeNumber: episode.number,
            episodeTitle: episode.title.resolved,
            positionSeconds: position,
            kind: kind,
            note: normalizedNote
        )
        sceneMarks.insert(mark, at: 0)
        persist()
        return mark
    }

    func deleteSceneMark(id: SceneMark.ID) {
        sceneMarks.removeAll { $0.id == id }
        persist()
    }

    func preparePlayback(for mark: SceneMark, in drama: Drama) {
        guard mark.dramaID == drama.id, drama.episode(id: mark.episodeID) != nil else { return }
        var run = run(for: drama)
        run.watch(episodeID: mark.episodeID, position: mark.positionSeconds, markWatched: false)
        runs[drama.id] = run
        recordWatch(drama: drama, episodeID: mark.episodeID)
    }

    func resetAllProgress() {
        runs = [:]
        favoriteDramaIDs = []
        history = []
        sceneMarks = []
        persist()
    }

    func deleteLocalAccount() {
        isRestoring = true
        runs = [:]
        favoriteDramaIDs = []
        history = []
        sceneMarks = []
        preferences = AppPreferences()
        hasCompletedOnboarding = false
        isRestoring = false
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func recordWatch(drama: Drama, episodeID: String) {
        let entry = WatchHistoryEntry(id: drama.id, dramaID: drama.id, episodeID: episodeID, watchedAt: .now)
        history.removeAll { $0.dramaID == drama.id }
        history.insert(entry, at: 0)
        persist()
    }

    private func restore() {
        guard let data = defaults.data(forKey: Self.storageKey), let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        isRestoring = true
        runs = state.runs
        favoriteDramaIDs = state.favoriteDramaIDs
        history = state.history
        sceneMarks = state.sceneMarks ?? []
        preferences = state.preferences
        hasCompletedOnboarding = state.hasCompletedOnboarding
        isRestoring = false
    }

    private func persist() {
        guard !isRestoring else { return }
        let state = PersistedState(
            runs: runs,
            favoriteDramaIDs: favoriteDramaIDs,
            history: history,
            sceneMarks: sceneMarks,
            preferences: preferences,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }
}

private struct PersistedState: Codable {
    let runs: [String: DramaRun]
    let favoriteDramaIDs: Set<String>
    let history: [WatchHistoryEntry]
    let sceneMarks: [SceneMark]?
    let preferences: AppPreferences
    let hasCompletedOnboarding: Bool
}
