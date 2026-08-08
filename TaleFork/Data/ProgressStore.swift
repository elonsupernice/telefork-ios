import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {
    private(set) var runs: [String: StoryRun] = [:]
    private(set) var savedQuotes: [SavedQuote] = []
    var preferences = AppPreferences() {
        didSet { persist() }
    }
    var hasCompletedOnboarding = false {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let storageKey = "talefork.user-state.v1"
    private var isRestoring = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
#if DEBUG
        if ProcessInfo.processInfo.environment["TALEFORK_UI_PREVIEW"] == "1" {
            hasCompletedOnboarding = true
        }
#endif
    }

    func run(for story: Story) -> StoryRun {
        runs[story.id] ?? StoryRun(story: story)
    }

    func start(_ story: Story) {
        if runs[story.id] == nil {
            runs[story.id] = StoryRun(story: story)
            persist()
        }
    }

    func choose(_ choice: StoryChoice, in story: Story) {
        var run = run(for: story)
        run.choose(choice, in: story)
        runs[story.id] = run
        persist()
    }

    func restart(_ story: Story) {
        var run = run(for: story)
        run.restart(with: story)
        runs[story.id] = run
        persist()
    }

    func toggleQuote(storyID: String, sceneID: String, text: String) {
        let identifier = "\(storyID).\(sceneID)"
        if let index = savedQuotes.firstIndex(where: { $0.id == identifier }) {
            savedQuotes.remove(at: index)
        } else {
            savedQuotes.insert(
                SavedQuote(
                    id: identifier,
                    storyID: storyID,
                    sceneID: sceneID,
                    text: text,
                    savedAt: .now
                ),
                at: 0
            )
        }
        persist()
    }

    func isQuoteSaved(storyID: String, sceneID: String) -> Bool {
        savedQuotes.contains { $0.id == "\(storyID).\(sceneID)" }
    }

    func removeQuote(id: String) {
        savedQuotes.removeAll { $0.id == id }
        persist()
    }

    func resetAllProgress() {
        runs = [:]
        savedQuotes = []
        persist()
    }

    private func restore() {
        guard
            let data = defaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }

        isRestoring = true
        runs = state.runs
        savedQuotes = state.savedQuotes
        preferences = state.preferences
        hasCompletedOnboarding = state.hasCompletedOnboarding
        isRestoring = false
    }

    private func persist() {
        guard !isRestoring else { return }
        let state = PersistedState(
            runs: runs,
            savedQuotes: savedQuotes,
            preferences: preferences,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private struct PersistedState: Codable {
    let runs: [String: StoryRun]
    let savedQuotes: [SavedQuote]
    let preferences: AppPreferences
    let hasCompletedOnboarding: Bool
}
