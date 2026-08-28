import Foundation

enum MembershipAccess {
    static let weeklyProductID = "com.talefork.storypaths.vip.weekly"
    static let freeEpisodeCount = 10

    static func requiresSubscription(forEpisodeNumber episodeNumber: Int) -> Bool {
        episodeNumber > freeEpisodeCount
    }
}
