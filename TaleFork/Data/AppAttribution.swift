import Foundation

enum AttributionSource: String, Sendable {
    case unknown
    case meta
    case google
    case appleAds

    var isPaidSource: Bool {
        switch self {
        case .meta, .google, .appleAds: true
        case .unknown: false
        }
    }
}

struct AttributionSnapshot: Sendable, Equatable {
    let source: AttributionSource
    let promotionID: String?
    let adID: String?
    let adSetID: String?
    let clickID: String?

    var hasEvidence: Bool {
        [promotionID, adID, adSetID, clickID].contains { value in
            guard let value else { return false }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !normalized.isEmpty && normalized != "0"
        }
    }

    var isPaid: Bool { source.isPaidSource && hasEvidence }
}

@MainActor
final class AttributionStore {
    static let shared = AttributionStore()

    private let defaults = UserDefaults.standard
    private let sourceKey = "talefork.attribution.source.v2"
    private let promotionIDKey = "talefork.attribution.promotion-id.v2"
    private let adIDKey = "talefork.attribution.ad-id.v2"
    private let adSetIDKey = "talefork.attribution.ad-set-id.v2"
    private let clickIDKey = "talefork.attribution.click-id.v2"

    private init() {}

    var snapshot: AttributionSnapshot {
        AttributionSnapshot(
            source: AttributionSource(rawValue: defaults.string(forKey: sourceKey) ?? "unknown") ?? .unknown,
            promotionID: value(forKey: promotionIDKey),
            adID: value(forKey: adIDKey),
            adSetID: value(forKey: adSetIDKey),
            clickID: value(forKey: clickIDKey)
        )
    }

    func ingest(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name.lowercased()] = item.value ?? ""
        }
        let sourceValue = query["utm_source"] ?? query["source"] ?? query["channel"]
        if let sourceValue {
            defaults.set(normalizeSource(sourceValue).rawValue, forKey: sourceKey)
        }
        let fbclid = query["fbclid"]
        let googleClick = query["gclid"] ?? query["gbraid"] ?? query["wbraid"]
        let appleClick = query["iad-attribution"] ?? query["iad-campaign-id"]
        if let fbclid, !fbclid.isEmpty {
            defaults.set(AttributionSource.meta.rawValue, forKey: sourceKey)
            defaults.set(fbclid, forKey: clickIDKey)
        } else if let googleClick, !googleClick.isEmpty {
            defaults.set(AttributionSource.google.rawValue, forKey: sourceKey)
            defaults.set(googleClick, forKey: clickIDKey)
        } else if let appleClick, !appleClick.isEmpty {
            defaults.set(AttributionSource.appleAds.rawValue, forKey: sourceKey)
            defaults.set(appleClick, forKey: clickIDKey)
        }
        setIfPresent(query["promotion_id"] ?? query["promotionid"], key: promotionIDKey)
        setIfPresent(query["ad_id"] ?? query["adid"], key: adIDKey)
        setIfPresent(query["adset_id"] ?? query["adsetid"], key: adSetIDKey)
    }

    func applyServerPromotionID(_ promotionID: String?) {
        guard let promotionID else { return }
        let normalized = promotionID.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty || normalized == "0" {
            clearPaidAttribution()
        } else {
            defaults.set(normalized, forKey: promotionIDKey)
        }
    }

    func clearPaidAttribution() {
        defaults.set(AttributionSource.unknown.rawValue, forKey: sourceKey)
        defaults.removeObject(forKey: promotionIDKey)
        defaults.removeObject(forKey: adIDKey)
        defaults.removeObject(forKey: adSetIDKey)
        defaults.removeObject(forKey: clickIDKey)
    }

    private func normalizeSource(_ value: String) -> AttributionSource {
        switch value.lowercased() {
        case "meta", "facebook", "fb", "instagram": .meta
        case "google", "googleads", "adwords": .google
        case "apple", "appleads", "searchads": .appleAds
        default: .unknown
        }
    }

    private func setIfPresent(_ value: String?, key: String) {
        guard let value, !value.isEmpty else { return }
        defaults.set(value, forKey: key)
    }

    private func value(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }
}

struct MembershipStatusContent: Decodable, Sendable {
    let vip: Bool
    let vipEndDate: String?
    var isCurrentlyValid: Bool {
        guard vip else { return false }
        guard let vipEndDate else { return true }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let end = formatter.date(from: vipEndDate) ?? ISO8601DateFormatter().date(from: vipEndDate)
        return end.map { $0 > Date() } ?? false
    }
}
