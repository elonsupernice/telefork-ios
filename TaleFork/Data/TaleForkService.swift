import Foundation
import Observation
import UIKit

private enum ServiceRoute: String {
    case visitorRegister = "api/user/visitorRegister"
    case appConfiguration = "api/user/appConfig"
    case discover = "api/drama/dramaDiscover"
    case search = "api/drama/dramaListByKeyword"
}

enum TaleForkServiceError: LocalizedError {
    case invalidResponse
    case rejected(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "service.invalid.response")
        case let .rejected(message): return message
        case .decoding: return String(localized: "service.invalid.data")
        }
    }
}

private struct ServiceEnvelope<Payload: Decodable>: Decodable {
    let status: Int
    let msg: String?
    let data: Payload?
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

private struct VisitorPayload: Decodable {
    let id: String
    let token: String

    private enum CodingKeys: String, CodingKey { case id, token }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.tolerantString(.id)
        token = values.tolerantString(.token)
    }
}

private struct CatalogBootstrap {
    let userID: String
    let dramas: [Drama]
}

private struct ConfigurationPayload: Decodable {
    let resourceHost: URL

    private enum CodingKeys: String, CodingKey { case resourceHost = "dramaResHost" }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let raw = values.tolerantString(.resourceHost)
        guard let url = URL(string: raw), !raw.isEmpty else { throw TaleForkServiceError.decoding }
        resourceHost = url
    }
}

private struct DiscoveryPayload: Decodable {
    let dramas: [RemoteDrama]
}

private struct CatalogPayload: Decodable {
    let list: [RemoteDrama]
    let topFive: [RemoteDrama]
    let topNine: [RemoteDrama]

    private enum CodingKeys: String, CodingKey { case list, topFive = "top5", topNine = "top9" }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        list = values.tolerantArray(RemoteDrama.self, .list)
        topFive = values.tolerantArray(RemoteDrama.self, .topFive)
        topNine = values.tolerantArray(RemoteDrama.self, .topNine)
    }
}

private struct RemoteDrama: Decodable {
    let id: String
    let title: String
    let summary: String
    let coverURL: URL?
    let totalEpisodes: Int

    private enum CodingKeys: String, CodingKey {
        case id, title, total, coverImage
        case summary = "desc"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.tolerantString(.id)
        title = values.tolerantString(.title)
        summary = values.tolerantString(.summary)
        coverURL = URL(string: values.tolerantString(.coverImage))
        totalEpisodes = max(values.tolerantInteger(.total, fallback: 1), 1)
    }

    func appDrama(resourceHost: URL) -> Drama {
        let episodes = (1...totalEpisodes).map { number in
            let episodeTitle = String(format: String(localized: "remote.episode.title"), number)
            return DramaEpisode(
                id: "\(id)-\(number)",
                number: number,
                title: .server(episodeTitle),
                sceneCaption: .server(summary),
                clipName: "",
                videoURL: resourceHost
                    .appendingPathComponent("video")
                    .appendingPathComponent(id)
                    .appendingPathComponent("\(number).mp4"),
                durationSeconds: 1
            )
        }
        return Drama(
            id: id,
            title: .server(title),
            subtitle: .server(summary),
            synopsis: .server(summary),
            posterImageName: "",
            coverURL: coverURL,
            accentHex: accentColor,
            availability: .available,
            entryEpisodeID: episodes[0].id,
            episodes: episodes
        )
    }

    private var accentColor: String {
        let palette = ["E6A84C", "59C4BE", "6570C5", "E7796B", "60A5A8"]
        let seed = id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
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
private final class TaleForkService {
    private let baseURL = URL(string: "https://djhk.shujuku009.xyz/")!
    private let deviceIDKey = "talefork.service-device-id"
    private var token = ""

    func bootstrap() async throws -> CatalogBootstrap {
        let visitor: VisitorPayload = try await post(.visitorRegister, body: devicePayload, requiresToken: false)
        token = visitor.token
        let configuration: ConfigurationPayload = try await post(.appConfiguration, body: devicePayload)
        let discovery: DiscoveryPayload = try await post(.discover, body: [:])
        return CatalogBootstrap(
            userID: visitor.id,
            dramas: discovery.dramas.map { $0.appDrama(resourceHost: configuration.resourceHost) }
        )
    }

    func search(_ keyword: String) async throws -> [Drama] {
        guard !token.isEmpty else {
            return try await bootstrap().dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(keyword)
            }
        }
        let configuration: ConfigurationPayload = try await post(.appConfiguration, body: devicePayload)
        let catalog: CatalogPayload = try await post(
            .search,
            body: ["keyword": .text(keyword), "pageNumber": .number(1), "pageSize": .number(50)]
        )
        return catalog.list.map { $0.appDrama(resourceHost: configuration.resourceHost) }
    }

    func clearLocalIdentity() {
        token = ""
        UserDefaults.standard.removeObject(forKey: deviceIDKey)
    }

    private func post<Payload: Decodable>(
        _ route: ServiceRoute,
        body: [String: JSONScalar],
        requiresToken: Bool = true
    ) async throws -> Payload {
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Bundle.main.bundleIdentifier ?? "com.talefork.storypaths", forHTTPHeaderField: "pkg")
        request.setValue("IOS", forHTTPHeaderField: "platform")
        request.setValue("225", forHTTPHeaderField: "version")
        request.setValue("IOS", forHTTPHeaderField: "channel")
        request.setValue("[1]", forHTTPHeaderField: "encrypt")
        request.setValue(Self.languageCode, forHTTPHeaderField: "languageCode")
        if requiresToken, !token.isEmpty { request.setValue(token, forHTTPHeaderField: "Authorization") }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TaleForkServiceError.invalidResponse
        }
        guard let envelope = try? JSONDecoder().decode(ServiceEnvelope<Payload>.self, from: data) else {
            throw TaleForkServiceError.decoding
        }
        guard envelope.status == 0 else { throw TaleForkServiceError.rejected(envelope.msg ?? "") }
        guard let payload = envelope.data else { throw TaleForkServiceError.invalidResponse }
        return payload
    }

    private var devicePayload: [String: JSONScalar] {
        let defaults = UserDefaults.standard
        let deviceID = defaults.string(forKey: deviceIDKey) ?? UUID().uuidString
        defaults.set(deviceID, forKey: deviceIDKey)
        return [
            "androidId": .text(deviceID),
            "appName": .text("talefork"),
            "channel": .text("IOS"),
            "iOSDeviceId": .text(deviceID),
            "model": .text(UIDevice.current.model),
            "oaid": .text(deviceID),
            "pkg": .text(Bundle.main.bundleIdentifier ?? "com.talefork.storypaths"),
            "versionCode": .text("225"),
            "platform": .text("IOS"),
            "version": .text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"),
            "idfv": .text(UIDevice.current.identifierForVendor?.uuidString ?? deviceID)
        ]
    }

    private static var languageCode: String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh-Hant") { return "zh_HK" }
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
    private(set) var errorMessage: String?

    private let service = TaleForkService()
    private var hasLoaded = false

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
            dramas = []
            searchResults = []
        }
    }

    func retry() async { await load(force: true) }

    func deleteLocalAccount() {
        service.clearLocalIdentity()
        currentUserID = ""
        dramas = []
        searchResults = []
        errorMessage = nil
        hasLoaded = false
    }

    func search(keyword: String) async {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { searchResults = []; return }
        do {
            searchResults = try await service.search(value)
        } catch {
            searchResults = dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(value)
            }
        }
    }
}
