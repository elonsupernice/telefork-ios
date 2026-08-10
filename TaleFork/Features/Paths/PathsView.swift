import SwiftUI

struct PathsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(CatalogStore.self) private var catalog
    @State private var playerDrama: Drama?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    SectionHeading(eyebrow: "paths.eyebrow", title: "paths.title")
                    Text("paths.subtitle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if catalog.isLoading, catalog.dramas.isEmpty {
                        ProgressView("discover.loading")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if let drama = currentDrama {
                        viewingSummary(for: drama)
                        episodeTimeline(for: drama)
                        continueButton(for: drama)
                    } else {
                        ContentUnavailableView(
                            "paths.empty.title",
                            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                            description: Text("paths.empty.body")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding(.horizontal, TaleForkTheme.horizontalMargin(for: proxy.size.width))
                .padding(.top, 20)
                .padding(.bottom, 112)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
        }
        .navigationTitle("tab.paths")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playerDrama) { drama in
            DramaPlayerView(drama: drama)
        }
        .task { await catalog.load() }
    }

    private var currentDrama: Drama? {
        progress.history
            .sorted { $0.watchedAt > $1.watchedAt }
            .compactMap { catalog.drama(id: $0.dramaID) }
            .first
    }

    private func viewingSummary(for drama: Drama) -> some View {
        let run = progress.run(for: drama)
        return HStack(spacing: 14) {
            BundleImage(name: drama.posterImageName, remoteURL: drama.coverURL)
                .scaledToFill()
                .frame(width: 72, height: 94)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(drama.title.resolved)
                    .font(.title3.bold())
                    .lineLimit(2)
                Text(String(
                    format: String(localized: "paths.progress.format"),
                    run.watchedEpisodeIDs.count,
                    drama.episodes.count
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                ProgressView(
                    value: Double(run.watchedEpisodeIDs.count),
                    total: Double(max(drama.episodes.count, 1))
                )
                .tint(TaleForkTheme.coral)
            }
            Spacer(minLength: 8)
            Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                .font(.title2)
                .foregroundStyle(TaleForkTheme.accentText)
        }
        .padding(18)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func episodeTimeline(for drama: Drama) -> some View {
        let run = progress.run(for: drama)
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(drama.episodes.enumerated()), id: \.element.id) { index, episode in
                episodeRow(episode, drama: drama, run: run, isLast: index == drama.episodes.count - 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func episodeRow(_ episode: DramaEpisode, drama: Drama, run: DramaRun, isLast: Bool) -> some View {
        let watched = run.watchedEpisodeIDs.contains(episode.id)
        let current = run.currentEpisodeID == episode.id
        return Button {
            TactileFeedback.tap(enabled: progress.preferences.tactileFeedbackEnabled)
            progress.selectEpisode(drama: drama, episodeID: episode.id)
            playerDrama = drama
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(current ? TaleForkTheme.coral : (watched ? TaleForkTheme.mint : TaleForkTheme.mist))
                            .frame(width: 34, height: 34)
                        Image(systemName: current ? "play.fill" : (watched ? "checkmark" : "circle"))
                            .font(.caption.bold())
                            .foregroundStyle(current || watched ? TaleForkTheme.ink : .secondary)
                    }
                    if !isLast {
                        Rectangle()
                            .fill(watched ? TaleForkTheme.mint.opacity(0.72) : TaleForkTheme.mist)
                            .frame(width: 2, height: 34)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: String(localized: "player.episode.format"), episode.number))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(current ? TaleForkTheme.accentText : .secondary)
                    Text(episode.title.resolved)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(.top, 1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(
            format: String(localized: "paths.episode.accessibility"),
            episode.number,
            current ? String(localized: "paths.current") : (watched ? String(localized: "paths.watched") : String(localized: "paths.unwatched"))
        )))
    }

    private func continueButton(for drama: Drama) -> some View {
        Button {
            TactileFeedback.tap(enabled: progress.preferences.tactileFeedbackEnabled)
            progress.start(drama)
            playerDrama = drama
        } label: {
            Label("drama.continue", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(TaleForkTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(TaleForkTheme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityHint(Text("paths.continue.hint"))
    }
}
