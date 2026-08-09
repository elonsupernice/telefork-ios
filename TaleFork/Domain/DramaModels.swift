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
    let genre: LocalizedCopy
    let tags: [LocalizedCopy]
    let year: Int
    let posterImageName: String
    let accentHex: String
    let availability: DramaAvailability
    let entryEpisodeID: String
    let episodes: [DramaEpisode]

    var endings: [DramaEpisode] { episodes.filter { $0.ending != nil } }
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
    let durationSeconds: Int
    let choices: [DramaChoice]
    let ending: DramaEnding?
}

struct DramaChoice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: LocalizedCopy
    let consequence: LocalizedCopy
    let destinationEpisodeID: String
}

struct DramaEnding: Codable, Hashable, Sendable {
    let title: LocalizedCopy
    let summary: LocalizedCopy
    let symbol: String
}

struct DramaRun: Codable, Hashable, Sendable {
    let dramaID: String
    var currentEpisodeID: String
    var watchedEpisodeIDs: [String]
    var selectedChoiceIDs: [String]
    var completedEndingIDs: Set<String>
    var playbackSeconds: [String: Double]
    var updatedAt: Date

    init(drama: Drama) {
        dramaID = drama.id
        currentEpisodeID = drama.entryEpisodeID
        watchedEpisodeIDs = []
        selectedChoiceIDs = []
        completedEndingIDs = []
        playbackSeconds = [:]
        updatedAt = .now
    }

    mutating func watch(episodeID: String, position: Double = 0) {
        currentEpisodeID = episodeID
        playbackSeconds[episodeID] = max(position, 0)
        if !watchedEpisodeIDs.contains(episodeID) { watchedEpisodeIDs.append(episodeID) }
        updatedAt = .now
    }

    mutating func choose(_ choice: DramaChoice, in drama: Drama) {
        guard drama.episode(id: choice.destinationEpisodeID) != nil else { return }
        selectedChoiceIDs.append(choice.id)
        currentEpisodeID = choice.destinationEpisodeID
        if drama.episode(id: choice.destinationEpisodeID)?.ending != nil {
            completedEndingIDs.insert(choice.destinationEpisodeID)
        }
        updatedAt = .now
    }

    mutating func restart(with drama: Drama) {
        currentEpisodeID = drama.entryEpisodeID
        watchedEpisodeIDs = []
        selectedChoiceIDs = []
        playbackSeconds = [:]
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
    var hapticsEnabled = true
    var reduceDecorativeMotion = false
    var autoplayEnabled = true
    var preferredGenres: Set<String> = []
}
