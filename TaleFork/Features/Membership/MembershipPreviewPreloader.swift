import AVFoundation
import Network

/// Two paused, muted previews at most. Playback takes ownership of the same
/// player/item, retaining its buffer rather than issuing a throwaway download.
@MainActor
final class MembershipPreviewPreloader {
    static let shared = MembershipPreviewPreloader()
    private var players: [URL: AVPlayer] = [:]
    private var prepared = Set<URL>()
    private var inUse: [URL: Int] = [:]
    private let pathMonitor = NWPathMonitor()

    init() { pathMonitor.start(queue: DispatchQueue(label: "TaleFork.preview-network")) }

    var allowsPrefetch: Bool {
        pathMonitor.currentPath.status == .satisfied && !pathMonitor.currentPath.isConstrained
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func waitForInitialNetworkPath() async {
        // NWPathMonitor publishes asynchronously even on an already connected
        // device. Do not permanently skip the first run because of its default path.
        for _ in 0..<10 {
            guard pathMonitor.currentPath.status != .satisfied, !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func stage(_ url: URL) {
        guard allowsPrefetch, players[url] == nil, inUse[url, default: 0] == 0, players.count < 2 else { return }
        players[url] = Self.makePlayer(url: url)
    }

    func preload(_ urls: [URL]) async {
        for url in urls.prefix(2) {
            guard !Task.isCancelled, allowsPrefetch else { return }
            stage(url)
            guard let player = players[url], !prepared.contains(url) else { continue }
            let deadline = Date().addingTimeInterval(6)
            while player.status == .unknown && Date() < deadline && !Task.isCancelled && players[url] === player {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard !Task.isCancelled, players[url] === player else { return }
            guard player.status == .readyToPlay else {
                discard(url)
                continue
            }
            // AVPlayer requires readyToPlay and rate == 0 for preroll.
            player.preroll(atRate: 1) { [weak self, weak player] finished in
                Task { @MainActor in
                    guard let self, let player, self.players[url] === player, finished else { return }
                    self.prepared.insert(url)
                }
            }
            while !prepared.contains(url) && Date() < deadline && !Task.isCancelled && players[url] === player {
                try? await Task.sleep(for: .milliseconds(100))
            }
            // A visible page may already have taken this player. Never pause
            // or tear down a player once ownership has moved to playback.
            if players[url] === player { player.cancelPendingPrerolls() }
        }
    }

    func acquire(_ url: URL) -> (player: AVPlayer, wasPreloaded: Bool) {
        inUse[url, default: 0] += 1
        prepared.remove(url)
        if let player = players.removeValue(forKey: url) {
            player.cancelPendingPrerolls()
            if player.currentItem?.status != .failed { return (player, true) }
            player.replaceCurrentItem(with: nil)
        }
        return (Self.makePlayer(url: url), false)
    }

    func release(_ player: AVPlayer, url: URL) {
        player.pause()
        player.cancelPendingPrerolls()
        player.replaceCurrentItem(with: nil)
        inUse[url] = max(0, inUse[url, default: 1] - 1)
    }

    func clearUnused() {
        for url in Array(players.keys) { discard(url) }
    }

    private func discard(_ url: URL) {
        let player = players.removeValue(forKey: url)
        player?.pause()
        player?.cancelPendingPrerolls()
        player?.replaceCurrentItem(with: nil)
        prepared.remove(url)
    }

    private static func makePlayer(url: URL) -> AVPlayer {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 3
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        player.isMuted = true
        player.volume = 1
        // No play() or audio-session activation occurs during preparation.
        return player
    }
}
