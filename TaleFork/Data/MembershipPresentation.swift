import Foundation

enum MembershipPresentationRoute: String, Sendable {
    case appStore
    case hostedPage
}

struct MembershipPresentationConfiguration: Sendable {
    let reviewModel: Bool?
    let showVip: Bool?
    let allowedHosts: Set<String>

    var route: MembershipPresentationRoute {
        let review = reviewModel ?? showVip.map { !$0 } ?? true
        return review ? .appStore : .hostedPage
    }

    func accepts(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.user == nil && url.password == nil
            && (url.port == nil || url.port == 443)
            && url.host.map { allowedHosts.contains($0.lowercased()) } == true
    }
}

struct HostedMembershipOffer: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let displayPrice: String
    let vipDesc: String
    let trailDesc: String
    let isDefault: Bool

    var isDisplayable: Bool {
        [id, title, displayPrice].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, displayPrice, vipDesc, trailDesc, `default`
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        displayPrice = try values.decodeIfPresent(String.self, forKey: .displayPrice) ?? ""
        vipDesc = try values.decodeIfPresent(String.self, forKey: .vipDesc) ?? ""
        trailDesc = try values.decodeIfPresent(String.self, forKey: .trailDesc) ?? ""
        isDefault = try values.decodeIfPresent(Bool.self, forKey: .default) ?? false
    }
}

struct HostedMembershipOfferCollection: Decodable, Sendable {
    let offers: [HostedMembershipOffer]
}

struct HostedMembershipPage: Decodable, Identifiable, Sendable {
    let payDetail: URL
    let checkoutID: String
    let status: String
    let expiresAt: String
    var id: String { checkoutID }

    var isPendingAndUnexpired: Bool {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let end = fractional.date(from: expiresAt) ?? ISO8601DateFormatter().date(from: expiresAt)
        return !checkoutID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && status == "CREATED" && end.map { $0 > Date() } == true
    }
}

struct MembershipPresentationSnapshot: Sendable {
    let configuration: MembershipPresentationConfiguration
    let offers: [HostedMembershipOffer]
}
