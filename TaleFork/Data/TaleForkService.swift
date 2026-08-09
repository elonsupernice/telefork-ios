import Foundation
import Observation
import UIKit

private enum ServiceRoute: String {
    case visitorRegister = "api/user/visitorRegister"
    case smsCode = "api/user/getSmsCode"
    case appConfiguration = "api/user/appConfig"
    case bindMobile = "api/user/bindMobileBySmsCode"
    case dramaCategories = "api/drama/dramaTypes"
    case dramasByCategory = "api/drama/dramaListByType"
    case hotRecommendations = "api/drama/hotRecommend"
    case profileSummary = "api/welfare/myData"
    case history = "api/user/getHistoryRecord"
    case discover = "api/drama/dramaDiscover"
    case unfollow = "api/user/cancelFollowDrama"
    case follow = "api/user/addFollowDrama"
    case watchlist = "api/user/getFollowDrama"
    case removeWatchlistItems = "api/user/cancelFollowDramas"
    case search = "api/drama/dramaListByKeyword"
    case welfare = "api/welfare/index"
    case refreshUser = "api/user/fetchUser"
    case dramaDetail = "api/drama/dramaInfo"
    case redPacketCheck = "api/user/redPacketCheck"
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
    let message: String?
    let data: Payload?

    private enum CodingKeys: String, CodingKey {
        case status, data
        case message = "msg"
    }
}

private struct VisitorPayload: Decodable {
    let token: String
}

private struct ConfigurationPayload: Decodable {
    let resourceHost: URL

    private enum CodingKeys: String, CodingKey { case resourceHost = "dramaResHost" }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? values.decode(String.self, forKey: .resourceHost)) ?? ""
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
        list = (try? values.decode([RemoteDrama].self, forKey: .list)) ?? []
        topFive = (try? values.decode([RemoteDrama].self, forKey: .topFive)) ?? []
        topNine = (try? values.decode([RemoteDrama].self, forKey: .topNine)) ?? []
    }
}

private struct RemoteDrama: Decodable {
    let id: String
    let title: String
    let summary: String
    let coverURL: URL?
    let totalEpisodes: Int
    let category: String

    private enum CodingKeys: String, CodingKey {
        case id, title, type, total, coverImage
        case summary = "desc"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? values.decode(String.self, forKey: .id)) ?? ""
        title = (try? values.decode(String.self, forKey: .title)) ?? ""
        summary = (try? values.decode(String.self, forKey: .summary)) ?? ""
        coverURL = URL(string: (try? values.decode(String.self, forKey: .coverImage)) ?? "")
        totalEpisodes = max((try? values.decode(Int.self, forKey: .total)) ?? 1, 1)
        category = (try? values.decode(String.self, forKey: .type)) ?? ""
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
                durationSeconds: 1,
                choices: [],
                ending: nil
            )
        }
        return Drama(
            id: id,
            title: .server(title),
            subtitle: .server(summary),
            synopsis: .server(summary),
            genre: .server(category),
            tags: [],
            year: Calendar.current.component(.year, from: .now),
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

@MainActor
private final class TaleForkService {
    private let baseURL = URL(string: "https://djhk.shujuku009.xyz/")!
    private var token = ""

    func bootstrap() async throws -> [Drama] {
        let visitor: VisitorPayload = try await post(.visitorRegister, body: devicePayload, requiresToken: false)
        token = visitor.token
        let configuration: ConfigurationPayload = try await post(.appConfiguration, body: devicePayload)
        let discovery: DiscoveryPayload = try await post(.discover, body: [:])
        return discovery.dramas.map { $0.appDrama(resourceHost: configuration.resourceHost) }
    }

    func search(_ keyword: String) async throws -> [Drama] {
        guard !token.isEmpty else { return try await bootstrap().filter { $0.title.resolved.localizedCaseInsensitiveContains(keyword) } }
        let configuration: ConfigurationPayload = try await post(.appConfiguration, body: devicePayload)
        let catalog: CatalogPayload = try await post(
            .search,
            body: ["keyword": keyword, "pageNumber": 1, "pageSize": 50]
        )
        return catalog.list.map { $0.appDrama(resourceHost: configuration.resourceHost) }
    }

    private func post<Payload: Decodable>(
        _ route: ServiceRoute,
        body: [String: Any],
        requiresToken: Bool = true
    ) async throws -> Payload {
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
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
        guard envelope.status == 0 else { throw TaleForkServiceError.rejected(envelope.message ?? "") }
        guard let payload = envelope.data else { throw TaleForkServiceError.invalidResponse }
        return payload
    }

    private var devicePayload: [String: Any] {
        let defaults = UserDefaults.standard
        let key = "talefork.service-device-id"
        let deviceID = defaults.string(forKey: key) ?? UUID().uuidString
        defaults.set(deviceID, forKey: key)
        return [
            "androidId": deviceID,
            "appName": "talefork",
            "channel": "IOS",
            "iOSDeviceId": deviceID,
            "model": UIDevice.current.model,
            "oaid": deviceID,
            "pkg": Bundle.main.bundleIdentifier ?? "com.talefork.storypaths",
            "versionCode": "225",
            "platform": "IOS",
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            "idfv": UIDevice.current.identifierForVendor?.uuidString ?? deviceID
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
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var usesOfflineFallback = false

    private let service = TaleForkService()
    private var hasLoaded = false

    var featured: Drama? { dramas.first }

    func drama(id: String) -> Drama? {
        dramas.first { $0.id == id } ?? DramaLibrary.drama(id: id)
    }

    func load(force: Bool = false) async {
        guard force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let remote = try await service.bootstrap()
            guard !remote.isEmpty else { throw TaleForkServiceError.invalidResponse }
            dramas = remote
            usesOfflineFallback = false
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            usesOfflineFallback = true
            dramas = DramaLibrary.dramas
        }
    }

    func retry() async { await load(force: true) }

    func search(keyword: String) async {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { searchResults = []; return }
        do {
            searchResults = try await service.search(value)
        } catch {
            searchResults = dramas.filter {
                $0.title.resolved.localizedCaseInsensitiveContains(value)
                || $0.genre.resolved.localizedCaseInsensitiveContains(value)
            }
        }
    }
}
