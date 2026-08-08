import Foundation

struct LocalizedCopy: Codable, Hashable, Sendable {
    let zhHant: String
    let en: String
    let ja: String

    var resolved: String {
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        if language == "ja" { return ja }
        if language == "zh" { return zhHant }
        return en
    }
}

struct Story: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: LocalizedCopy
    let subtitle: LocalizedCopy
    let synopsis: LocalizedCopy
    let genre: LocalizedCopy
    let estimatedMinutes: Int
    let symbol: String
    let palette: StoryPalette
    let entrySceneID: String
    let scenes: [StoryScene]

    var endings: [StoryScene] {
        scenes.filter { $0.ending != nil }
    }

    func scene(id: String) -> StoryScene? {
        scenes.first { $0.id == id }
    }
}

struct StoryScene: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let chapter: Int
    let heading: LocalizedCopy
    let body: LocalizedCopy
    let quote: LocalizedCopy?
    let choices: [StoryChoice]
    let ending: StoryEnding?
}

struct StoryChoice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: LocalizedCopy
    let hint: LocalizedCopy
    let destinationSceneID: String
}

struct StoryEnding: Codable, Hashable, Sendable {
    let title: LocalizedCopy
    let summary: LocalizedCopy
    let tone: EndingTone
}

enum EndingTone: String, Codable, Hashable, Sendable {
    case luminous
    case quiet
    case unresolved
}

struct StoryPalette: Codable, Hashable, Sendable {
    let startHex: String
    let endHex: String
    let accentHex: String
}

struct StoryRun: Codable, Hashable, Sendable {
    let storyID: String
    var currentSceneID: String
    var visitedSceneIDs: [String]
    var selectedChoiceIDs: [String]
    var completedEndingIDs: Set<String>
    var updatedAt: Date

    init(story: Story) {
        storyID = story.id
        currentSceneID = story.entrySceneID
        visitedSceneIDs = [story.entrySceneID]
        selectedChoiceIDs = []
        completedEndingIDs = []
        updatedAt = .now
    }

    mutating func choose(_ choice: StoryChoice, in story: Story) {
        guard story.scene(id: choice.destinationSceneID) != nil else { return }
        selectedChoiceIDs.append(choice.id)
        currentSceneID = choice.destinationSceneID
        visitedSceneIDs.append(choice.destinationSceneID)
        if story.scene(id: choice.destinationSceneID)?.ending != nil {
            completedEndingIDs.insert(choice.destinationSceneID)
        }
        updatedAt = .now
    }

    mutating func restart(with story: Story) {
        currentSceneID = story.entrySceneID
        visitedSceneIDs = [story.entrySceneID]
        selectedChoiceIDs = []
        updatedAt = .now
    }
}

struct SavedQuote: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let storyID: String
    let sceneID: String
    let text: String
    let savedAt: Date
}

struct AppPreferences: Codable, Hashable, Sendable {
    enum Appearance: String, Codable, CaseIterable, Identifiable, Sendable {
        case system
        case light
        case dark

        var id: String { rawValue }
    }

    var appearance: Appearance = .system
    var hapticsEnabled = true
    var reduceDecorativeMotion = false
    var preferredGenres: Set<String> = []
}

