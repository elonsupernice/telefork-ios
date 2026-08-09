import SwiftUI

struct PathsView: View {
    @Environment(ProgressStore.self) private var store
    @State private var showPlayer = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeading(eyebrow: "paths.eyebrow", title: "paths.title")
                    Text("paths.subtitle").foregroundStyle(.secondary)

                    routeMap
                    endingCollection

                    Button {
                        store.start(DramaLibrary.beforeRainStops); showPlayer = true
                    } label: {
                        Label(store.runs[DramaLibrary.beforeRainStops.id] == nil ? "drama.start" : "drama.continue", systemImage: "play.fill")
                            .font(.headline).foregroundStyle(TaleForkTheme.ink).frame(maxWidth: .infinity, minHeight: 54)
                            .background(TaleForkTheme.coral, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, TaleForkTheme.horizontalMargin(for: proxy.size.width)).padding(.vertical, 20)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.background(PaperBackground())
        }
        .navigationTitle("tab.paths").navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) { DramaPlayerView(drama: DramaLibrary.beforeRainStops) }
    }

    private var routeMap: some View {
        let drama = DramaLibrary.beforeRainStops
        let run = store.run(for: drama)
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                BundleImage(name: drama.posterImageName).scaledToFill().frame(width: 58, height: 74).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(drama.title.resolved).font(.headline)
                    Text(String(format: String(localized: "paths.progress.format"), run.watchedEpisodeIDs.count, drama.episodes.count)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.triangle.branch").font(.title2).foregroundStyle(TaleForkTheme.coral)
            }

            routeRow(episode: drama.episodes[0], depth: 0, run: run)
            routeConnector(split: true)
            HStack(alignment: .top, spacing: 12) {
                VStack { routeRow(episode: drama.episodes[2], depth: 1, run: run); routeConnector(split: false); routeRow(episode: drama.episodes[4], depth: 2, run: run) }
                VStack { routeRow(episode: drama.episodes[3], depth: 1, run: run); routeConnector(split: false); routeRow(episode: drama.episodes[5], depth: 2, run: run) }
            }
        }.padding(18).background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
    }

    private func routeRow(episode: DramaEpisode, depth: Int, run: DramaRun) -> some View {
        let unlocked = run.watchedEpisodeIDs.contains(episode.id) || run.currentEpisodeID == episode.id
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(unlocked ? TaleForkTheme.mint : TaleForkTheme.mist).frame(width: 32, height: 32)
                Image(systemName: unlocked ? (episode.ending == nil ? "play.fill" : "seal.fill") : "lock.fill")
                    .font(.caption).foregroundStyle(unlocked ? TaleForkTheme.ink : .secondary)
            }
            Text(unlocked ? episode.title.resolved : String(localized: "paths.unknown.node"))
                .font(.caption.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
        }.frame(maxWidth: .infinity)
    }

    private func routeConnector(split: Bool) -> some View {
        Image(systemName: split ? "arrow.triangle.branch" : "arrow.down")
            .foregroundStyle(TaleForkTheme.coral.opacity(0.7)).frame(maxWidth: .infinity)
    }

    private var endingCollection: some View {
        let drama = DramaLibrary.beforeRainStops
        let unlocked = store.run(for: drama).completedEndingIDs
        return VStack(alignment: .leading, spacing: 14) {
            Text("paths.endings.title").font(.title3.bold())
            HStack(spacing: 12) {
                ForEach(drama.endings) { episode in
                    let isUnlocked = unlocked.contains(episode.id)
                    VStack(spacing: 8) {
                        Image(systemName: isUnlocked ? (episode.ending?.symbol ?? "seal.fill") : "questionmark")
                            .font(.title2).foregroundStyle(isUnlocked ? TaleForkTheme.coral : .secondary)
                        Text(isUnlocked ? (episode.ending?.title.resolved ?? "") : String(localized: "paths.locked.ending"))
                            .font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, minHeight: 110)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }
}
