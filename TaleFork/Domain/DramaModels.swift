import Foundation

struct LocalizedCopy: Codable, Hashable, Sendable {
    let zhHant: String
    let en: String
    let ja: String

    var resolved: String {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        if language == "ja" { return ja }
        if language == "zh" { return zhHant }
        return en
    }

    static func server(_ value: String) -> LocalizedCopy {
        LocalizedCopy(zhHant: value, en: value, ja: value)
    }
}

enum DramaAvailability: String, Codable, Hashable, Sendable {
    case available
    case comingSoon
}

struct Drama: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: LocalizedCopy
    let subtitle: LocalizedCopy
    let synopsis: LocalizedCopy
    let posterImageName: String
    var coverURL: URL? = nil
    let accentHex: String
    let availability: DramaAvailability
    let entryEpisodeID: String
    let episodes: [DramaEpisode]

    var totalDuration: Int { episodes.reduce(0) { $0 + $1.durationSeconds } }

    func episode(id: String) -> DramaEpisode? {
        episodes.first { $0.id == id }
    }
}

struct DramaEpisode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let number: Int
    let title: LocalizedCopy
    let sceneCaption: LocalizedCopy
    let clipName: String
    var videoURL: URL? = nil
    let durationSeconds: Int
}

struct DramaRun: Codable, Hashable, Sendable {
    let dramaID: String
    var currentEpisodeID: String
    var watchedEpisodeIDs: [String]
    var playbackSeconds: [String: Double]
    var updatedAt: Date

    init(drama: Drama) {
        dramaID = drama.id
        currentEpisodeID = drama.entryEpisodeID
        watchedEpisodeIDs = []
        playbackSeconds = [:]
        updatedAt = .now
    }

    mutating func watch(episodeID: String, position: Double = 0, markWatched: Bool = true) {
        currentEpisodeID = episodeID
        playbackSeconds[episodeID] = max(position, 0)
        if markWatched, !watchedEpisodeIDs.contains(episodeID) { watchedEpisodeIDs.append(episodeID) }
        updatedAt = .now
    }

}

struct WatchHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let dramaID: String
    var episodeID: String
    var watchedAt: Date
}

struct AppPreferences: Codable, Hashable, Sendable {
    enum Appearance: String, Codable, CaseIterable, Identifiable, Sendable {
        case system, light, dark
        var id: String { rawValue }
    }

    var appearance: Appearance = .system
    var tactileFeedbackEnabled = true
    var reduceDecorativeMotion = false
    var autoplayEnabled = true
}
