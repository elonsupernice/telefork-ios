import Foundation
import Observation
import UIKit

private enum ServiceRoute: String {
    case heartbeat = "tale-gateway/v2/heartbeat"
    case devicePass = "tale-gateway/v2/identity/device-pass"
    case launchManifest = "tale-gateway/v2/launch/manifest"
    case lineup = "tale-gateway/v2/screenings/lineup"
    case search = "tale-gateway/v2/screenings/search"
}

enum TaleForkServiceError: LocalizedError {
    case invalidResponse
    case rejected(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "service.invalid.response")
        case let .rejected(detail): return detail
        case .decoding: return String(localized: "service.invalid.data")
        }
    }
}

private struct MobileEnvelope<Content: Decodable>: Decodable {
    let outcome: String
    let detail: String?
    let content: Content?
}

private extension KeyedDecodingContainer {
    func tolerantString(_ key: Key) -> String {
        if let text = try? decode(String.self, forKey: key) { return text }
        if let integer = try? decode(Int64.self, forKey: key) { return String(integer) }
        return ""
    }

    func tolerantInteger(_ key: Key, fallback: Int) -> Int {
        if let integer = try? decode(Int.self, forKey: key) { return integer }
        if let text = try? decode(String.self, forKey: key), let integer = Int(text) { return integer }
        return fallback
    }

    func tolerantArray<Element: Decodable>(_ type: Element.Type, _ key: Key) -> [Element] {
        (try? decode([Element].self, forKey: key)) ?? []
    }
}

private struct DevicePassContent: Decodable {
    let audienceKey: String
    let accessPass: String

    private enum CodingKeys: String, CodingKey {
        case audienceKey
        case accessPass
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        audienceKey = values.tolerantString(.audienceKey)
        accessPass = values.tolerantString(.accessPass)
    }
}

struct CatalogBootstrap {
    let userID: String
    let dramas: [Drama]
}

@MainActor
protocol CatalogServing: AnyObject {
    func bootstrap() async throws -> CatalogBootstrap
    func search(_ keyword: String) async throws -> [Drama]
    func deleteAccount() async throws
    func clearLocalIdentity()
}

private struct IdentityRemovalContent: Decodable {
    let identityRemoved: Bool
}

private struct LaunchManifestContent: Decodable {
    let assetRoot: URL

    private enum CodingKeys: String, CodingKey { case assetRoot }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let raw = values.tolerantString(.assetRoot)
        guard let url = URL(string: raw), !raw.isEmpty else { throw TaleForkServiceError.decoding }
        assetRoot = url
    }
}

private struct ScreeningContent: Decodable {
    let stories: [RemoteStory]

    private enum CodingKeys: String, CodingKey { case stories }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        stories = values.tolerantArray(RemoteStory.self, .stories)
    }
}

private struct RemoteStory: Decodable {
    let storyKey: String
    let displayTitle: String
    let storyBlurb: String
    let artworkLink: URL?
    let chapterTotal: Int
    let displayRank: Int

    private enum CodingKeys: String, CodingKey {
        case storyKey
        case displayTitle
        case storyBlurb
        case artworkLink
        case chapterTotal
        case displayRank
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        storyKey = values.tolerantString(.storyKey)
        displayTitle = values.tolerantString(.displayTitle)
        storyBlurb = values.tolerantString(.storyBlurb)
        artworkLink = URL(string: values.tolerantString(.artworkLink))
        chapterTotal = max(values.tolerantInteger(.chapterTotal, fallback: 1), 1)
        displayRank = values.tolerantInteger(.displayRank, fallback: 0)
    }

    func appDrama(assetRoot: URL) -> Drama {
        let episodes = (1...chapterTotal).map { number in
            let episodeTitle = String(format: String(localized: "remote.episode.title"), number)
            return DramaEpisode(
                id: "\(storyKey)-\(number)",
                number: number,
                title: .server(episodeTitle),
                sceneCaption: .server(storyBlurb),
                clipName: "",
                videoURL: assetRoot
                    .appendingPathComponent("stories")
                    .appendingPathComponent(storyKey)
                    .appendingPathComponent("reels")
                    .appendingPathComponent(String(number))
                    .appendingPathComponent("playback.mp4"),
                durationSeconds: 1
            )
        }
        return Drama(
            id: storyKey,
            title: .server(displayTitle),
            subtitle: .server(storyBlurb),
            storySummary: .server(storyBlurb),
            posterImageName: "",
            coverURL: artworkLink,
            accentHex: accentColor,
            availability: .available,
            entryEpisodeID: episodes[0].id,
            episodes: episodes
        )
    }

    private var accentColor: String {
        let palette = ["E6A84C", "59C4BE", "6570C5", "E7796B", "60A5A8"]
        let seed = storyKey.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return palette[abs(seed) % palette.count]
    }
}

private enum JSONScalar: Encodable {
    case text(String)
    case number(Int)

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case let .text(text): try value.encode(text)
        case let .number(number): try value.encode(number)
        }
    }
}

@MainActor
final class TaleForkService: CatalogServing {
    private let baseURL: URL
    private let deviceSeedKey = "talefork.service-device-id"
    private var accessPass = ""

    init() {
#if DEBUG
        if let override = ProcessInfo.processInfo.environment["TALEFORK_SERVICE_BASE_URL"],
           let url = URL(string: override) {
            baseURL = url
            return
        }
#endif
        baseURL = URL(string: "https://app.duanjufafafa.fun/")!
    }

    func bootstrap() async throws -> CatalogBootstrap {
        let identity: DevicePassContent = try await post(.devicePass, body: devicePassRequest, requiresPass: false)
        accessPass = identity.accessPass
        let manifest: LaunchManifestContent = try await post(.launchManifest, body: launchRequest)
        let screening: ScreeningContent = try await post(.lineup, body: ["maximumStories": .number(50)])
        return CatalogBootstrap(
            userID: identity.audienceKey,
            dramas: screening.stories.map { $0.appDrama(assetRoot: manifest.assetRoot) }
        )
    }

    func search(_ keyword: String) async throws -> [Drama] {
        guard !accessPass.isEmpty else {
            return try await bootstrap().dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(keyword)
            }
        }
        let manifest: LaunchManifestContent = try await post(.launchManifest, body: launchRequest)
        let screening: ScreeningContent = try await post(
            .search,
            body: ["searchText": .text(keyword), "maximumStories": .number(50)]
        )
        return screening.stories.map { $0.appDrama(assetRoot: manifest.assetRoot) }
    }

    func deleteAccount() async throws {
        guard !accessPass.isEmpty else {
            clearLocalIdentity()
            return
        }
        let result: IdentityRemovalContent = try await delete(.devicePass)
        guard result.identityRemoved else { throw TaleForkServiceError.invalidResponse }
        clearLocalIdentity()
    }

    func clearLocalIdentity() {
        accessPass = ""
        UserDefaults.standard.removeObject(forKey: deviceSeedKey)
    }

    private func post<Content: Decodable>(
        _ route: ServiceRoute,
        body: [String: JSONScalar],
        requiresPass: Bool = true
    ) async throws -> Content {
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("talefork-ios-r2", forHTTPHeaderField: "X-TaleFork-Edition")
        if requiresPass, !accessPass.isEmpty {
            request.setValue(accessPass, forHTTPHeaderField: "X-TaleFork-Pass")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TaleForkServiceError.invalidResponse
        }
        guard let envelope = try? JSONDecoder().decode(MobileEnvelope<Content>.self, from: data) else {
            throw TaleForkServiceError.decoding
        }
        guard envelope.outcome == "READY" else { throw TaleForkServiceError.rejected(envelope.detail ?? "") }
        guard let content = envelope.content else { throw TaleForkServiceError.invalidResponse }
        return content
    }

    private func delete<Content: Decodable>(_ route: ServiceRoute) async throws -> Content {
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("talefork-ios-r2", forHTTPHeaderField: "X-TaleFork-Edition")
        request.setValue(accessPass, forHTTPHeaderField: "X-TaleFork-Pass")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TaleForkServiceError.invalidResponse
        }
        guard let envelope = try? JSONDecoder().decode(MobileEnvelope<Content>.self, from: data) else {
            throw TaleForkServiceError.decoding
        }
        guard envelope.outcome == "READY" else { throw TaleForkServiceError.rejected(envelope.detail ?? "") }
        guard let content = envelope.content else { throw TaleForkServiceError.invalidResponse }
        return content
    }

    private var devicePassRequest: [String: JSONScalar] {
        let defaults = UserDefaults.standard
        let deviceSeed = defaults.string(forKey: deviceSeedKey) ?? UUID().uuidString
        defaults.set(deviceSeed, forKey: deviceSeedKey)
        return [
            "deviceSeed": .text(deviceSeed),
            "releaseName": .text(releaseName),
            "releaseBuild": .text(releaseBuild),
            "languageTag": .text(Self.languageTag),
            "hardwareFamily": .text(UIDevice.current.model)
        ]
    }

    private var launchRequest: [String: JSONScalar] {
        ["releaseName": .text(releaseName), "releaseBuild": .text(releaseBuild)]
    }

    private var releaseName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var releaseBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private static var languageTag: String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh-Hant") { return "zh-HK" }
        if language.hasPrefix("zh-Hans") { return "zh" }
        if language.hasPrefix("ko") { return "ko" }
        if language.hasPrefix("id") { return "id" }
        if language.hasPrefix("ms") { return "ms" }
        if language.hasPrefix("fil") || language.hasPrefix("tl") { return "tl" }
        if language.hasPrefix("th") { return "th" }
        if language.hasPrefix("ja") { return "ja" }
        return "en"
    }
}

@MainActor
@Observable
final class CatalogStore {
    private(set) var dramas: [Drama] = []
    private(set) var searchResults: [Drama] = []
    private(set) var currentUserID = ""
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var errorMessage: String?
    private(set) var searchErrorMessage: String?

    private let service: any CatalogServing
    private var hasLoaded = false
    private var searchRequestID = UUID()

    init(service: any CatalogServing = TaleForkService()) {
        self.service = service
    }

    var featured: Drama? { dramas.first }

    func drama(id: String) -> Drama? {
        dramas.first { $0.id == id }
    }

    func load(force: Bool = false) async {
        guard force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let bootstrap = try await service.bootstrap()
            guard !bootstrap.dramas.isEmpty else { throw TaleForkServiceError.invalidResponse }
            dramas = bootstrap.dramas
            currentUserID = bootstrap.userID
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            if dramas.isEmpty { searchResults = [] }
        }
    }

    func retry() async { await load(force: true) }

    @discardableResult
    func deleteAccount() async -> Bool {
        do {
            try await service.deleteAccount()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        currentUserID = ""
        dramas = []
        searchResults = []
        errorMessage = nil
        searchErrorMessage = nil
        hasLoaded = false
        searchRequestID = UUID()
        return true
    }

    func search(keyword: String) async {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestID = UUID()
        searchRequestID = requestID
        guard !value.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }
        isSearching = true
        searchErrorMessage = nil
        defer {
            if searchRequestID == requestID { isSearching = false }
        }
        do {
            let results = try await service.search(value)
            guard searchRequestID == requestID, !Task.isCancelled else { return }
            searchResults = results
        } catch {
            guard searchRequestID == requestID, !Task.isCancelled else { return }
            searchResults = dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(value)
            }
            searchErrorMessage = error.localizedDescription
        }
    }
}
