import AVFoundation
import SwiftUI

struct DramaPlayerView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let drama: Drama

    @State private var player = AVPlayer()
    @State private var currentEpisodeID: String
    @State private var showCompletion = false
    @State private var showEpisodePicker = false
    @State private var controlsVisible = true
    @State private var playbackFailed = false
    @State private var isBuffering = true
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var playbackSeconds = 0.0
    @State private var durationSeconds = 1.0
    @State private var pendingResumeSeconds: Double?
    @State private var lastPersistedSecond = -1

    private let playbackClock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(drama: Drama) {
        self.drama = drama
        _currentEpisodeID = State(initialValue: drama.entryEpisodeID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PortraitVideoCanvas(player: player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }
                .accessibilityElement()
                .accessibilityLabel(Text("player.video"))
                .accessibilityHint(Text("player.video.hint"))
                .accessibilityAction(.magicTap) { togglePlayback() }

            if controlsVisible && !showCompletion && !playbackFailed { controlOverlay.transition(.opacity) }
            if playbackFailed { failureOverlay }
            if showCompletion { completionOverlay.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            let stored = store.run(for: drama).currentEpisodeID
            currentEpisodeID = drama.episode(id: stored) == nil ? drama.entryEpisodeID : stored
            loadCurrentEpisode()
        }
        .onDisappear {
            persistPlaybackPosition()
            player.pause()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            player.pause()
            isPlaying = false
            controlsVisible = true
            persistPlaybackPosition()
        }
        .onReceive(playbackClock) { _ in refreshPlaybackState() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard notification.object as? AVPlayerItem === player.currentItem else { return }
            playbackSeconds = 0
            isPlaying = false
            store.watch(drama: drama, episodeID: currentEpisodeID, position: 0, completed: true)
            if let nextEpisode, store.preferences.autoplayEnabled {
                controlsVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    guard currentEpisodeID != nextEpisode.id else { return }
                    selectEpisode(nextEpisode.id)
                }
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { showCompletion = true; controlsVisible = true }
            }
        }
        .sheet(isPresented: $showEpisodePicker) { EpisodePickerSheet(drama: drama, currentEpisodeID: currentEpisodeID) { selectEpisode($0) } }
    }

    private var episode: DramaEpisode? { drama.episode(id: currentEpisodeID) }

    private var nextEpisode: DramaEpisode? {
        guard let episode, let index = drama.episodes.firstIndex(where: { $0.id == episode.id }) else { return nil }
        let nextIndex = drama.episodes.index(after: index)
        return drama.episodes.indices.contains(nextIndex) ? drama.episodes[nextIndex] : nil
    }

    private var controlOverlay: some View {
        GeometryReader { proxy in
            let topScrimHeight = max(proxy.safeAreaInsets.top + 150, 190)
            let bottomScrimHeight = max(proxy.safeAreaInsets.bottom + 300, 330)
            ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.82), .black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topScrimHeight)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.62), .black.opacity(0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bottomScrimHeight)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topControlBar
                Spacer(minLength: 8)
                centerPlaybackControls
                Spacer(minLength: 8)
                bottomControlPanel
            }
            .padding(.top, proxy.safeAreaInsets.top + 8)
            .padding(.bottom, proxy.safeAreaInsets.bottom + 8)
            .dynamicTypeSize(.xSmall ... .xxxLarge)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(true)
    }

    private var topControlBar: some View {
        ZStack(alignment: .top) {
            HStack {
                backButton
                Spacer()
                circleButton("rectangle.stack", accessibilityLabel: "player.episodes") { showEpisodePicker = true }
            }
            VStack(spacing: 2) {
                Text(drama.title.resolved)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(String(format: String(localized: "player.episode.format"), episode?.number ?? 1))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 108)
        }
        .padding(.horizontal, 16)
    }

    private var bottomControlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("player.featured.short")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(TaleForkTheme.coral)
            Text(episode?.title.resolved ?? "")
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text(episode?.sceneCaption.resolved ?? "")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
            HStack(spacing: 10) {
                Text(formatTime(playbackSeconds))
                Slider(
                    value: Binding(
                        get: { min(playbackSeconds, durationSeconds) },
                        set: { seek(to: $0) }
                    ),
                    in: 0...max(durationSeconds, 1)
                )
                .tint(TaleForkTheme.coral)
                .accessibilityLabel(Text("player.progress"))
                .accessibilityValue(Text("(formatTime(playbackSeconds)) / (formatTime(durationSeconds))"))
                Text("-\(formatTime(max(durationSeconds - playbackSeconds, 0)))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.74))
            HStack(spacing: 18) {
                Button { togglePlayback() } label: {
                    Label(isPlaying ? "player.pause" : "player.play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                Button {
                    TactileFeedback.tap(enabled: store.preferences.tactileFeedbackEnabled)
                    store.toggleFavorite(drama)
                } label: {
                    Label(store.isFavorite(drama) ? "player.saved" : "player.save", systemImage: store.isFavorite(drama) ? "heart.fill" : "heart")
                }
                Button { showEpisodePicker = true } label: { Label("player.episodes", systemImage: "list.number") }
                Spacer(minLength: 0)
                Button { toggleMute() } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(isMuted ? "player.unmute" : "player.mute"))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var centerPlaybackControls: some View {
        if isBuffering {
            VStack(spacing: 10) {
                ProgressView().controlSize(.large).tint(.white)
                Text("player.loading").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            HStack(spacing: 28) {
                transportButton("gobackward.10", label: "player.rewind") { seekRelative(-10) }
                Button { togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .frame(width: 72, height: 72)
                        .foregroundStyle(TaleForkTheme.ink)
                        .background(TaleForkTheme.coral.opacity(0.92), in: Circle())
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                }
                .accessibilityLabel(Text(isPlaying ? "player.pause" : "player.play"))
                transportButton("goforward.10", label: "player.forward") { seekRelative(10) }
            }
        }
    }

    private func transportButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .frame(width: 54, height: 54)
                .foregroundStyle(.white)
                .background(.black.opacity(0.42), in: Circle())
        }
        .accessibilityLabel(Text(label))
    }

    private var backButton: some View {
        Button {
            persistPlaybackPosition()
            player.pause()
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("common.back")
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background(.black.opacity(0.42), in: Capsule())
        }
        .foregroundStyle(.white)
        .accessibilityLabel(Text("common.back"))
    }

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    backButton
                    Spacer()
                    circleButton("rectangle.stack", accessibilityLabel: "player.episodes") { showEpisodePicker = true }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                Spacer(minLength: 8)
                if let nextEpisode {
                    Image(systemName: "forward.end.fill").font(.system(size: 42)).foregroundStyle(TaleForkTheme.coral)
                    Text(nextEpisode.title.resolved).font(.system(.title2, design: .rounded, weight: .black)).foregroundStyle(.white)
                    Button { selectEpisode(nextEpisode.id) } label: {
                        Label("player.next", systemImage: "play.fill").primaryPlayerButton()
                    }
                    Button { showCompletion = false; player.seek(to: .zero); player.play() } label: {
                        Label("player.rewatch", systemImage: "gobackward").font(.subheadline).foregroundStyle(.white.opacity(0.72)).frame(minHeight: 44)
                    }
                } else {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(TaleForkTheme.coral)
                    Text("player.series.complete").font(.system(.title2, design: .rounded, weight: .black)).foregroundStyle(.white)
                    Button { dismiss() } label: { Text("common.done").primaryPlayerButton() }
                }
                Spacer().frame(height: 20)
            }.padding(.horizontal, 22).frame(maxWidth: 520)
        }
    }

    private var failureOverlay: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    backButton
                    Spacer()
                    circleButton("rectangle.stack", accessibilityLabel: "player.episodes") { showEpisodePicker = true }
                }
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(TaleForkTheme.coral)
                    Text("player.error.title").font(.headline).foregroundStyle(.white)
                    Text("player.error.body").font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                    Button("common.retry") { playbackFailed = false; loadCurrentEpisode() }
                        .buttonStyle(.borderedProminent).tint(TaleForkTheme.coral)
                    if currentEpisodeID != drama.entryEpisodeID {
                        Button("player.restart.first") { selectEpisode(drama.entryEpisodeID) }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(minHeight: 44)
                    }
                }
                .padding(24)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                Spacer()
            }
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 8)
            .safeAreaPadding(.bottom, 8)
        }
    }

    private func circleButton(
        _ symbol: String,
        accessibilityLabel: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.headline).frame(width: 44, height: 44).background(.black.opacity(0.34), in: Circle()) }
            .foregroundStyle(.white)
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private func loadCurrentEpisode() {
        guard let episode else { playbackFailed = true; isBuffering = false; return }
        let bundledURL = Bundle.main.url(forResource: episode.clipName, withExtension: "mp4")
        guard let url = episode.videoURL ?? bundledURL else { playbackFailed = true; isBuffering = false; return }
        showCompletion = false
        playbackFailed = false
        isBuffering = true
        controlsVisible = true
        playbackSeconds = 0
        durationSeconds = Double(max(episode.durationSeconds, 1))
        lastPersistedSecond = -1
        let savedPosition = store.run(for: drama).playbackSeconds[episode.id] ?? 0
        pendingResumeSeconds = savedPosition > 0 ? savedPosition : nil
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
#if DEBUG
            print("TaleFork player audio session failed: \(error.localizedDescription)")
#endif
            playbackFailed = true
            isBuffering = false
            isPlaying = false
            return
        }
        player.automaticallyWaitsToMinimizeStalling = false
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        )
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2
        player.replaceCurrentItem(with: item)
        player.isMuted = isMuted
        store.selectEpisode(drama: drama, episodeID: episode.id)
        player.play()
        isPlaying = true
    }

    private func selectEpisode(_ episodeID: String) {
        persistPlaybackPosition()
        currentEpisodeID = episodeID
        showEpisodePicker = false
        loadCurrentEpisode()
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            persistPlaybackPosition()
            controlsVisible = true
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
    }

    private func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    private func seekRelative(_ offset: Double) {
        seek(to: playbackSeconds + offset)
    }

    private func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), durationSeconds)
        playbackSeconds = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        persistPlaybackPosition()
    }

    private func refreshPlaybackState() {
        if player.currentItem?.status == .failed {
#if DEBUG
            let itemError = player.currentItem?.error?.localizedDescription ?? "unknown player item error"
            let eventError = player.currentItem?.errorLog()?.events.last?.errorComment ?? "no media error comment"
            print("TaleFork player item failed: \(itemError); \(eventError)")
#endif
            playbackFailed = true
            isBuffering = false
            isPlaying = false
            controlsVisible = true
            return
        }
        if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
            durationSeconds = itemDuration
        }
        if let target = pendingResumeSeconds,
           player.currentItem?.status == .readyToPlay,
           durationSeconds > 1 {
            pendingResumeSeconds = nil
            let resumeSecond = target < durationSeconds - 0.75 ? target : 0
            playbackSeconds = resumeSecond
            if resumeSecond > 0 {
                player.seek(to: CMTime(seconds: resumeSecond, preferredTimescale: 600))
            }
        }
        let time = player.currentTime().seconds
        if time.isFinite { playbackSeconds = min(max(time, 0), durationSeconds) }
        isPlaying = player.timeControlStatus == .playing
        isBuffering = player.currentItem?.status == .unknown
            || player.timeControlStatus == .waitingToPlayAtSpecifiedRate

        let wholeSecond = Int(playbackSeconds)
        if wholeSecond != lastPersistedSecond, wholeSecond.isMultiple(of: 2) {
            lastPersistedSecond = wholeSecond
            persistPlaybackPosition()
        }
    }

    private func persistPlaybackPosition() {
        guard episode != nil else { return }
        store.watch(drama: drama, episodeID: currentEpisodeID, position: playbackSeconds)
    }

    private func formatTime(_ seconds: Double) -> String {
        let value = max(Int(seconds.rounded(.down)), 0)
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct EpisodePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let drama: Drama
    let currentEpisodeID: String
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List(drama.episodes) { episode in
                Button {
                    onSelect(episode.id); dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", episode.number)).font(.headline.monospacedDigit()).foregroundStyle(TaleForkTheme.coral)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(episode.title.resolved).font(.headline)
                            Text(String(format: String(localized: "player.episode.format"), episode.number)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if episode.id == currentEpisodeID { Image(systemName: "waveform").foregroundStyle(TaleForkTheme.mint) }
                    }.foregroundStyle(.primary)
                }
                .accessibilityLabel(Text(String(
                    format: String(localized: "drama.episode.accessibility"),
                    episode.number,
                    episode.title.resolved
                )))
                .accessibilityValue(episode.id == currentEpisodeID ? Text("paths.current") : Text(""))
                .accessibilityHint(Text("drama.episode.open.hint"))
            }
            .navigationTitle("player.episodes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

private extension View {
    func primaryPlayerButton() -> some View {
        self.font(.headline).foregroundStyle(TaleForkTheme.ink).frame(maxWidth: .infinity, minHeight: 54)
            .background(TaleForkTheme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
