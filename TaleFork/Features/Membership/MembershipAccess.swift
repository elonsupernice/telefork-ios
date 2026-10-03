import Foundation

enum MembershipAccess {
    static let weeklyProductID = "com.talefork.storypaths.vip.weekly"
    static let monthlyProductID = "com.talefork.storypaths.vip.monthly"
    static let quarterlyProductID = "com.talefork.storypaths.vip.quarterly"
    static let productIDs = [weeklyProductID, monthlyProductID, quarterlyProductID]

    static func isMembershipProduct(_ id: String) -> Bool { productIDs.contains(id) }

    static func hasAllProducts(in loadedIDs: [String]) -> Bool {
        Set(loadedIDs).isSuperset(of: productIDs)
    }

    static func periodKey(for id: String) -> String {
        switch id {
        case weeklyProductID: "membership.apple.weekly"
        case monthlyProductID: "membership.apple.monthly"
        case quarterlyProductID: "membership.apple.quarterly"
        default: "membership.navigation.title"
        }
    }
    static let freeEpisodeCount = 10

    static func requiresSubscription(forEpisodeNumber episodeNumber: Int) -> Bool {
        episodeNumber > freeEpisodeCount
    }
}
