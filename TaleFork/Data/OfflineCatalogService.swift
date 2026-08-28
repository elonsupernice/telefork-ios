#if DEBUG
import Foundation

@MainActor
final class OfflineCatalogService: CatalogServing {
    private let dramas: [Drama]

    init() {
        dramas = [
            Self.makeDrama(
                id: "single-scene-preview",
                title: "Single Scene Preview",
                subtitle: "A one-episode fixture that must stay off the showcase.",
                accentHex: "59C4BE",
                chapterCount: 1
            ),
            Self.makeDrama(
                id: "lantern-room",
                title: "The Lantern Room",
                subtitle: "A locked studio, one missing frame, and a clue hidden in the light.",
                accentHex: "E6A84C"
            ),
            Self.makeDrama(
                id: "after-the-last-train",
                title: "After the Last Train",
                subtitle: "Two strangers reconstruct a night from the moments they almost forgot.",
                accentHex: "6570C5"
            )
        ]
    }

    func bootstrap() async throws -> CatalogBootstrap {
        CatalogBootstrap(userID: "OFFLINE-PREVIEW", dramas: dramas)
    }

    func search(_ keyword: String) async throws -> [Drama] {
        dramas.filter {
            $0.title.resolved.localizedCaseInsensitiveContains(keyword)
                || $0.subtitle.resolved.localizedCaseInsensitiveContains(keyword)
        }
    }

    func deleteAccount() async throws {}

    func clearLocalIdentity() {}

    private static func makeDrama(
        id: String,
        title: String,
        subtitle: String,
        accentHex: String,
        chapterCount: Int = 12
    ) -> Drama {
        let episodes = (1...chapterCount).map { number in
            DramaEpisode(
                id: "\(id)-episode-\(number)",
                number: number,
                title: .server("Scene Study \(number)"),
                sceneCaption: .server("Offline simulator fixture for TaleFork scene-note verification."),
                clipName: "",
                videoURL: URL(string: "talefork-preview://\(id)/\(number)"),
                durationSeconds: 90
            )
        }
        return Drama(
            id: id,
            title: .server(title),
            subtitle: .server(subtitle),
            storySummary: .server(subtitle),
            posterImageName: "",
            coverURL: nil,
            accentHex: accentHex,
            availability: .available,
            entryEpisodeID: episodes[0].id,
            episodes: episodes
        )
    }
}
#endif
