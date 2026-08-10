import SwiftUI

struct ExploreView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @State private var query = ""
    @State private var playerDrama: Drama?

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header
                    searchField

                    if query.isEmpty {
                        featuredDrama(height: min(420, max(360, proxy.size.height * 0.58)))
                        continueWatching
                    }

                    if catalog.isLoading {
                        Label("discover.loading", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if let errorMessage = catalog.errorMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("discover.connection.title", systemImage: "wifi.exclamationmark")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button { Task { await catalog.retry() } } label: {
                                Label("discover.retry", systemImage: "arrow.clockwise")
                                    .font(.subheadline.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(TaleForkTheme.accentText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    SectionHeading(eyebrow: "discover.collection.eyebrow", title: query.isEmpty ? "discover.collection.title" : "discover.search.results")
                    if !query.isEmpty, let searchErrorMessage = catalog.searchErrorMessage {
                        Label(searchErrorMessage, systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !query.isEmpty, catalog.isSearching {
                        ProgressView("discover.searching")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if filteredDramas.isEmpty {
                        ContentUnavailableView(
                            query.isEmpty ? "discover.empty.title" : "discover.search.empty.title",
                            systemImage: query.isEmpty ? "film.stack" : "magnifyingglass",
                            description: Text(query.isEmpty ? "discover.empty.body" : "discover.search.empty.body")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        dramaGrid(width: proxy.size.width - margin * 2)
                    }

                }
                .padding(.horizontal, margin)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Drama.self) { DramaDetailView(drama: $0) }
        .fullScreenCover(item: $playerDrama) { drama in
            DramaPlayerView(drama: drama)
        }
        .task { await catalog.load() }
        .task(id: query) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(320)) }
            guard !Task.isCancelled else { return }
            await catalog.search(keyword: query)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 48)
            VStack(alignment: .leading, spacing: 0) {
                Text("TaleFork").font(.system(.title2, design: .rounded, weight: .black))
                Text("discover.brand.subtitle").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("discover.live.badge")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(TaleForkTheme.ink)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(TaleForkTheme.coral, in: Capsule())
        }
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("discover.search.placeholder", text: $query)
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text("discover.search.clear"))
            }
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
        .background(.background.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func featuredDrama(height: CGFloat) -> some View {
        if let featured = catalog.featured {
            NavigationLink(value: featured) {
                ZStack(alignment: .bottomLeading) {
                    BundleImage(name: featured.posterImageName, remoteURL: featured.coverURL)
                        .scaledToFill().frame(height: height).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("discover.featured").font(.caption.weight(.black).monospaced()).foregroundStyle(TaleForkTheme.coral)
                        Text(featured.title.resolved)
                            .font(.system(.largeTitle, design: .rounded, weight: .black)).foregroundStyle(.white)
                        Text(featured.subtitle.resolved)
                            .font(.subheadline).foregroundStyle(.white.opacity(0.82)).lineLimit(2)
                        HStack {
                            Label(String(format: String(localized: "drama.episodes.format"), featured.episodes.count), systemImage: "play.rectangle.on.rectangle")
                            Spacer()
                            Image(systemName: "play.fill")
                                .foregroundStyle(TaleForkTheme.ink).frame(width: 48, height: 48)
                                .background(TaleForkTheme.coral, in: Circle())
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    }
                    .padding(20)
                    .dynamicTypeSize(.xSmall ... .xxxLarge)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(featured.title.resolved))
            .accessibilityValue(Text(String(format: String(localized: "drama.episodes.format"), featured.episodes.count)))
            .accessibilityHint(Text("discover.open.details.hint"))
        }
    }

    @ViewBuilder private var continueWatching: some View {
        if let drama = continuingDrama {
            let run = store.run(for: drama)
            Button {
                store.start(drama)
                playerDrama = drama
            } label: {
                HStack(spacing: 15) {
                    BundleImage(name: drama.posterImageName, remoteURL: drama.coverURL).scaledToFill().frame(width: 78, height: 96).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("discover.continue").font(.caption.weight(.black).monospaced()).foregroundStyle(TaleForkTheme.accentText)
                        Text(drama.title.resolved).font(.headline)
                        Text(drama.episode(id: run.currentEpisodeID)?.title.resolved ?? "")
                            .font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(run.watchedEpisodeIDs.count), total: Double(max(drama.episodes.count, 1))).tint(TaleForkTheme.coral)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.title).foregroundStyle(TaleForkTheme.accentText)
                }
                .padding(14).foregroundStyle(.primary)
                .background(.background.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("discover.continue.hint"))
        }
    }

    private func dramaGrid(width: CGFloat) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(220, width), maximum: 360), spacing: 16)], spacing: 20) {
            ForEach(filteredDramas) { drama in
                NavigationLink(value: drama) { DramaPoster(drama: drama, height: 310) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(drama.title.resolved))
                    .accessibilityValue(Text(String(format: String(localized: "drama.episodes.format"), drama.episodes.count)))
                    .accessibilityHint(Text("discover.open.details.hint"))
            }
        }
    }

    private var continuingDrama: Drama? {
        store.history.compactMap { catalog.drama(id: $0.dramaID) }.first
    }

    private var filteredDramas: [Drama] {
        let source = query.isEmpty ? catalog.dramas : catalog.searchResults
        return source.filter { drama in
            query.isEmpty || drama.title.resolved.localizedCaseInsensitiveContains(query)
        }
    }
}

struct DramaDetailView: View {
    @Environment(ProgressStore.self) private var store
    let drama: Drama
    @State private var showPlayer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .bottomLeading) {
                    BundleImage(name: drama.posterImageName, remoteURL: drama.coverURL).scaledToFill().frame(height: 440).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(drama.title.resolved).font(.system(.largeTitle, design: .rounded, weight: .black)).foregroundStyle(.white)
                        Text(drama.subtitle.resolved).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }.padding(20)
                    .dynamicTypeSize(.xSmall ... .xxxLarge)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                HStack(spacing: 10) {
                    if drama.availability == .available {
                    Text(String(format: String(localized: "drama.episodes.format"), drama.episodes.count))
                    }
                }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)

                Text(drama.synopsis.resolved).font(.body).foregroundStyle(.secondary).lineSpacing(5)

                if drama.availability == .available {
                    HStack(spacing: 12) {
                        Button {
                            store.start(drama); showPlayer = true
                        } label: {
                            Label(store.runs[drama.id] == nil ? "drama.start" : "drama.continue", systemImage: "play.fill")
                                .font(.headline).foregroundStyle(TaleForkTheme.ink).frame(maxWidth: .infinity, minHeight: 54)
                                .background(TaleForkTheme.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        Button {
                            TactileFeedback.tap(enabled: store.preferences.tactileFeedbackEnabled)
                            store.toggleFavorite(drama)
                        } label: {
                            Image(systemName: store.isFavorite(drama) ? "heart.fill" : "heart")
                                .font(.title3).foregroundStyle(store.isFavorite(drama) ? .red : .primary)
                                .frame(width: 54, height: 54).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .accessibilityLabel(Text(store.isFavorite(drama) ? "player.saved" : "player.save"))
                    }
                    episodeList
                } else {
                    Label("drama.coming.body", systemImage: "clock.badge.checkmark")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 112)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(PaperBackground()).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) { DramaPlayerView(drama: drama) }
    }

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("drama.episodes.title").font(.title3.bold())
            ForEach(drama.episodes) { episode in
                Button {
                    TactileFeedback.tap(enabled: store.preferences.tactileFeedbackEnabled)
                    store.selectEpisode(drama: drama, episodeID: episode.id)
                    showPlayer = true
                } label: {
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", episode.number)).font(.headline.monospacedDigit()).foregroundStyle(TaleForkTheme.accentText)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title.resolved).font(.headline)
                            Text(String(format: String(localized: "player.episode.format"), episode.number)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: store.run(for: drama).watchedEpisodeIDs.contains(episode.id) ? "checkmark.circle.fill" : "play.circle")
                            .foregroundStyle(store.run(for: drama).watchedEpisodeIDs.contains(episode.id) ? TaleForkTheme.mint : .secondary)
                    }.padding(14).foregroundStyle(.primary).background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(
                    format: String(localized: "drama.episode.accessibility"),
                    episode.number,
                    episode.title.resolved
                )))
                .accessibilityHint(Text("drama.episode.open.hint"))
            }
        }
    }
}
