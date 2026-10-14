import AVFoundation
import SwiftUI
import UIKit

// THESIS: The user-pinned brown/gold membership composition for Apple membership products.
// OWN-WORLD: Original bronze crown, warm paper-gold type, real TaleFork posters.
// STORY: Browse the real dramas first, review concise access, select a real-priced plan.
// FIRST VIEWPORT: Full poster carousel above compact benefits and the fixed purchase dock.
// FORM: Reference bc08e3c6, without its brand, fabricated benefits or discounts.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md

enum MembershipStyle {
    static let background = Color(hex: "170E08")
    static let panel = Color(hex: "382315")
    static let selectedPanel = Color(hex: "68412A")
    static let gold = Color(hex: "E6AD42")
    static let countdownAccent = Color(hex: "8A1C11")
    static let lightGold = Color(hex: "FFE3AC")
    static let secondaryText = Color(hex: "D5B89D")
    static let buttonInk = Color(hex: "301B08")
    static let title = Color(hex: "FFE6BE")
    static let artworkPlaceholder = [Color(hex: "745B45"), Color(hex: "A38260")]
    static let artworkPlaceholderTint = Color(hex: "F2DCC0")
}

struct MembershipShowcase: View {
    let dramas: [Drama]
    var autoplay = false
    var isPlaybackActive = true
    var previewIdentifier = "membership-retention-video"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDramaID: String?

    private var featuredDramas: [Drama] {
        MembershipPreviewSource.featuredDramas(in: dramas)
    }

    private var selectedIndex: Int {
        featuredDramas.firstIndex { $0.id == selectedDramaID } ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("membership.presentation.hero.exclusive")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)

            if !featuredDramas.isEmpty {
                posterStage
            } else {
                Label("membership.benefit.episodes", systemImage: "play.rectangle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .foregroundStyle(MembershipStyle.title)
    }

    private var posterStage: some View {
        GeometryReader { proxy in
            let centerWidth = min(proxy.size.width * 0.48, 180)
            let sideWidth = min(proxy.size.width * 0.3, 116)
            ZStack {
                if featuredDramas.count > 1 {
                    poster(featuredDramas[(selectedIndex + featuredDramas.count - 1) % featuredDramas.count], width: sideWidth, height: 156)
                        .opacity(0.52)
                        .offset(x: -proxy.size.width * 0.29)
                    poster(featuredDramas[(selectedIndex + 1) % featuredDramas.count], width: sideWidth, height: 156)
                        .opacity(0.52)
                        .offset(x: proxy.size.width * 0.29)
                }
                Group {
                    if autoplay {
                        MembershipDramaPreview(drama: featuredDramas[selectedIndex], isVisible: isPlaybackActive,
                                               previewIdentifier: previewIdentifier)
                            .id(featuredDramas[selectedIndex].id)
                            .frame(width: centerWidth, height: 216)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        poster(featuredDramas[selectedIndex], width: centerWidth, height: 216)
                    }
                }
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.9), lineWidth: 2) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 220)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 32).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                shiftFeaturedDrama(by: value.translation.width < 0 ? 1 : -1)
            }
        )
        .accessibilityElement(children: autoplay ? .contain : .ignore)
        .accessibilityIdentifier("membership-exclusive-carousel")
        .accessibilityLabel(Text(featuredDramas[selectedIndex].title.resolved))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: shiftFeaturedDrama(by: 1)
            case .decrement: shiftFeaturedDrama(by: -1)
            @unknown default: break
            }
        }
    }

    private func shiftFeaturedDrama(by offset: Int) {
        guard featuredDramas.count > 1 else { return }
        let nextIndex = (selectedIndex + offset + featuredDramas.count) % featuredDramas.count
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            selectedDramaID = featuredDramas[nextIndex].id
        }
    }

    private func poster(_ drama: Drama, width: CGFloat, height: CGFloat) -> some View {
        BundleImage(assetName: drama.posterImageName, remoteURL: drama.coverURL,
                    placeholderColors: MembershipStyle.artworkPlaceholder,
                    placeholderTint: MembershipStyle.artworkPlaceholderTint)
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Only a real, free episode is previewed. Never substitute synthetic fixture
/// playback for a real player, or open a locked episode from the retention UI.
enum MembershipPreviewSource {
    static func featuredDramas(in dramas: [Drama]) -> [Drama] {
        Array(dramas.filter { $0.availability == .available }.prefix(5))
    }

    static func url(for drama: Drama) -> URL? {
        drama.episodes.sorted { $0.number < $1.number }.first {
            !MembershipAccess.requiresSubscription(forEpisodeNumber: $0.number)
                && $0.videoURL?.scheme?.lowercased() == "https"
        }?.videoURL
    }
}

// Shared by the subscription and retention screens. Only the visible preview
// owns playback; checkout and backgrounding must silence it.
struct MembershipDramaPreview: View {
    @Environment(MembershipStore.self) private var membership
    @Environment(\.scenePhase) private var scenePhase
    let drama: Drama
    let isVisible: Bool
    let previewIdentifier: String
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var isPlaying = false
    @State private var playbackSeconds = 0.0
    @State private var playbackAllowed = false
    @State private var wasPreloaded = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BundleImage(assetName: drama.posterImageName, remoteURL: drama.coverURL,
                            placeholderColors: MembershipStyle.artworkPlaceholder,
                            placeholderTint: MembershipStyle.artworkPlaceholderTint)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                if let player, isReady {
                    MembershipPreviewCanvas(player: player)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .allowsHitTesting(false)
                        .onAppear { updatePlayback() }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(drama.title.resolved))
                        .accessibilityValue(playbackAccessibilityValue)
                        .accessibilityIdentifier(previewIdentifier)
                }
            }
        }
        .task(id: drama.id) {
            guard let url = MembershipPreviewSource.url(for: drama) else { return }
            let prepared = MembershipPreviewPreloader.shared.acquire(url)
            let preview = prepared.player
            wasPreloaded = prepared.wasPreloaded
            player = preview
            updatePlayback()
            defer {
                MembershipPreviewPreloader.shared.release(preview, url: url)
                if player === preview { player = nil; isReady = false; isPlaying = false }
            }
            // Cancellation owns cleanup. Do not deactivate the shared audio
            // session here: the main drama player uses the same category.
            while !Task.isCancelled {
                isReady = preview.currentItem?.status == .readyToPlay
                isPlaying = preview.timeControlStatus == .playing
                let seconds = preview.currentTime().seconds
                playbackSeconds = seconds.isFinite ? seconds : 0
                if preview.currentItem?.status == .failed { break }
                if let duration = preview.currentItem?.duration.seconds,
                   duration.isFinite, duration > 0, seconds >= duration - 0.2, playbackAllowed {
                    await preview.seek(to: .zero)
                    if !Task.isCancelled && playbackAllowed { preview.play() }
                }
                // Keep the control-free preview aligned with playback intent,
                // including readiness after returning from checkout/background.
                if isReady && canPlay && preview.timeControlStatus == .paused {
                    updatePlayback()
                }
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { break }
            }
        }
        .onChange(of: scenePhase) { _, _ in updatePlayback() }
        .onChange(of: isVisible) { _, _ in updatePlayback() }
        .onChange(of: membership.isPresentingCheckout) { _, _ in updatePlayback() }
        .onDisappear { playbackAllowed = false; player?.pause() }
    }

    private var canPlay: Bool {
        // The preference controls autoplay of the next full episode, not VIP previews.
        isVisible && scenePhase == .active && !membership.isPresentingCheckout
    }

    private var playbackAccessibilityValue: Text {
#if DEBUG
        // Diagnostic value derives from the real AVPlayer clock, not a fixture.
        Text(verbatim: "\(isPlaying ? "playing" : "paused"):\(String(format: "%.1f", playbackSeconds));allowed=\(playbackAllowed);muted=\(player?.isMuted ?? true);volume=\(player?.volume ?? 0);preloaded=\(wasPreloaded);audio=\(AVAudioSession.sharedInstance().category.rawValue);mode=\(AVAudioSession.sharedInstance().mode.rawValue)")
#else
        Text(isPlaying ? "membership.preview.playing" : "membership.preview.paused")
#endif
    }

    private func updatePlayback() {
        guard let player else { return }
        guard canPlay, player.currentItem?.status == .readyToPlay else {
            playbackAllowed = false
            player.pause()
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
            player.isMuted = false
            playbackAllowed = true
            player.play()
        } catch {
            playbackAllowed = false
            player.pause()
#if DEBUG
            print("TaleFork membership preview audio session failed: \(error.localizedDescription)")
#endif
        }
    }
}

/// Inline membership decoration has no transport controls or controller-owned
/// playback gestures. The normal drama player keeps its existing AVKit canvas.
private struct MembershipPreviewCanvas: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> MembershipPreviewSurface {
        let view = MembershipPreviewSurface()
        view.isUserInteractionEnabled = false
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: MembershipPreviewSurface, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }

    static func dismantleUIView(_ view: MembershipPreviewSurface, coordinator: Void) {
        view.playerLayer.player = nil
    }
}

private final class MembershipPreviewSurface: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct MembershipPlanCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let price: String
    let detail: String
    let isSelected: Bool
    var isHorizontal = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Group {
                if isHorizontal && !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            selectionText
                            planTitle
                            planDetail
                        }
                        Spacer(minLength: 0)
                        planPrice
                        selectionMark
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            selectionText
                            Spacer(minLength: 1)
                            selectionMark
                        }
                        planTitle
                        planPrice
                        planDetail
                    }
                }
            }
            .padding(isHorizontal ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: isHorizontal ? 92 : 148, alignment: .leading)
            .background(isSelected ? MembershipStyle.selectedPanel : MembershipStyle.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(isSelected ? MembershipStyle.gold : MembershipStyle.secondaryText.opacity(0.3), lineWidth: isSelected ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [title, price, detail]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectionText: some View {
        Text(isSelected ? "membership.presentation.selected" : "membership.presentation.option")
            .font(.caption2.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isSelected ? MembershipStyle.lightGold : MembershipStyle.secondaryText)
    }

    private var selectionMark: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.body.weight(.medium))
            .foregroundStyle(isSelected ? MembershipStyle.gold : MembershipStyle.secondaryText)
            .accessibilityHidden(true)
    }

    private var planTitle: some View {
        Text(verbatim: title).font(.headline.bold())
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(MembershipStyle.title)
    }

    private var planPrice: some View {
        Text(verbatim: price).font(.title3.bold())
            .minimumScaleFactor(0.7).lineLimit(1)
            .foregroundStyle(MembershipStyle.title)
    }

    @ViewBuilder private var planDetail: some View {
        if !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(verbatim: detail).font(.caption)
                .foregroundStyle(MembershipStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
