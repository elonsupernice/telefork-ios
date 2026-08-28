import Foundation

enum SceneMarkKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case turningPoint
    case line
    case clue
    case revisit

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .turningPoint: String(localized: "scene.mark.kind.turning")
        case .line: String(localized: "scene.mark.kind.line")
        case .clue: String(localized: "scene.mark.kind.clue")
        case .revisit: String(localized: "scene.mark.kind.revisit")
        }
    }

    var symbolName: String {
        switch self {
        case .turningPoint: "arrow.triangle.branch"
        case .line: "quote.bubble"
        case .clue: "eye"
        case .revisit: "bookmark"
        }
    }
}

struct SceneMark: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let dramaID: String
    let dramaTitle: String
    let episodeID: String
    let episodeNumber: Int
    let episodeTitle: String
    let positionSeconds: Double
    let kind: SceneMarkKind
    let note: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        dramaID: String,
        dramaTitle: String,
        episodeID: String,
        episodeNumber: Int,
        episodeTitle: String,
        positionSeconds: Double,
        kind: SceneMarkKind,
        note: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.dramaID = dramaID
        self.dramaTitle = dramaTitle
        self.episodeID = episodeID
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
        self.positionSeconds = max(positionSeconds, 0)
        self.kind = kind
        self.note = note
        self.createdAt = createdAt
    }
}
