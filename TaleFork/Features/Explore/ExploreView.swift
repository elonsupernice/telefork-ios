import SwiftUI

struct ExploreView: View {
    @Environment(ProgressStore.self) private var store
    @State private var query = ""
    @State private var selectedGenre = "all"

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header
                    searchField

                    if query.isEmpty {
                        featuredDrama
                        continueWatching
                        genreRail
                    }

                    SectionHeading(eyebrow: "discover.collection.eyebrow", title: query.isEmpty ? "discover.collection.title" : "discover.search.results")
                    dramaGrid(width: proxy.size.width - margin * 2)

                    originalNotice
                }
                .padding(.horizontal, margin)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Drama.self) { DramaDetailView(drama: $0) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 48)
            VStack(alignment: .leading, spacing: 0) {
                Text("TaleFork").font(.system(.title2, design: .rounded, weight: .black))
                Text("discover.brand.subtitle").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("discover.original.badge")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(TaleForkTheme.ink)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(TaleForkTheme.coral, in: Capsule())
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("discover.search.placeholder", text: $query)
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
        .background(.background.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var featuredDrama: some View {
        NavigationLink(value: DramaLibrary.beforeRainStops) {
            ZStack(alignment: .bottomLeading) {
                BundleImage(name: DramaLibrary.beforeRainStops.posterImageName)
                    .scaledToFill().frame(height: 420).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text("discover.featured").font(.caption.weight(.black).monospaced()).foregroundStyle(TaleForkTheme.coral)
                    Text(DramaLibrary.beforeRainStops.title.resolved)
                        .font(.system(.largeTitle, design: .rounded, weight: .black)).foregroundStyle(.white)
                    Text(DramaLibrary.beforeRainStops.subtitle.resolved)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.82)).lineLimit(2)
                    HStack {
                        Label(String(format: String(localized: "drama.episodes.format"), DramaLibrary.beforeRainStops.episodes.count), systemImage: "play.rectangle.on.rectangle")
                        Label(String(format: String(localized: "drama.endings.format"), DramaLibrary.beforeRainStops.endings.count), systemImage: "arrow.triangle.branch")
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundStyle(TaleForkTheme.ink).frame(width: 48, height: 48)
                            .background(TaleForkTheme.coral, in: Circle())
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var continueWatching: some View {
        if let drama = continuingDrama {
            let run = store.run(for: drama)
            NavigationLink(value: drama) {
                HStack(spacing: 15) {
                    BundleImage(name: drama.posterImageName).scaledToFill().frame(width: 78, height: 96).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("discover.continue").font(.caption.weight(.black).monospaced()).foregroundStyle(TaleForkTheme.coral)
                        Text(drama.title.resolved).font(.headline)
                        Text(drama.episode(id: run.currentEpisodeID)?.title.resolved ?? "")
                            .font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(run.watchedEpisodeIDs.count), total: Double(max(drama.episodes.count, 1))).tint(TaleForkTheme.coral)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.title).foregroundStyle(TaleForkTheme.coral)
                }
                .padding(14).foregroundStyle(.primary)
                .background(.background.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }.buttonStyle(.plain)
        }
    }

    private var genreRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                genreChip("all", "genre.all")
                genreChip("mystery", "genre.mystery")
                genreChip("emotional", "genre.emotional")
                genreChip("speculative", "genre.speculative")
            }
        }.scrollIndicators(.hidden)
    }

    private func genreChip(_ id: String, _ title: LocalizedStringKey) -> some View {
        Button { selectedGenre = id } label: {
            Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 40)
                .foregroundStyle(selectedGenre == id ? TaleForkTheme.paper : .primary)
                .background(selectedGenre == id ? TaleForkTheme.ink : Color.primary.opacity(0.07), in: Capsule())
        }.buttonStyle(.plain)
    }

    private func dramaGrid(width: CGFloat) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(220, width), maximum: 360), spacing: 16)], spacing: 20) {
            ForEach(filteredDramas) { drama in
                NavigationLink(value: drama) { DramaPoster(drama: drama, height: 310) }.buttonStyle(.plain)
            }
        }
    }

    private var originalNotice: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(TaleForkTheme.mint)
            VStack(alignment: .leading, spacing: 5) {
                Text("discover.original.title").font(.headline)
                Text("discover.original.body").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(18).background(TaleForkTheme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var continuingDrama: Drama? {
        store.history.compactMap { DramaLibrary.drama(id: $0.dramaID) }.first
    }

    private var filteredDramas: [Drama] {
        DramaLibrary.dramas.filter { drama in
            let matchesQuery = query.isEmpty || drama.title.resolved.localizedCaseInsensitiveContains(query) || drama.genre.resolved.localizedCaseInsensitiveContains(query)
            let matchesGenre: Bool
            switch selectedGenre {
            case "mystery": matchesGenre = drama.genre.en.localizedCaseInsensitiveContains("mystery")
            case "emotional": matchesGenre = drama.genre.en.localizedCaseInsensitiveContains("emotional")
            case "speculative": matchesGenre = drama.genre.en.localizedCaseInsensitiveContains("sci") || drama.genre.en.localizedCaseInsensitiveContains("fantasy")
            default: matchesGenre = true
            }
            return matchesQuery && matchesGenre
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
                    BundleImage(name: drama.posterImageName).scaledToFill().frame(height: 440).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(drama.genre.resolved.uppercased()).font(.caption.weight(.black).monospaced()).foregroundStyle(Color(hex: drama.accentHex))
                        Text(drama.title.resolved).font(.system(.largeTitle, design: .rounded, weight: .black)).foregroundStyle(.white)
                        Text(drama.subtitle.resolved).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }.padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                HStack(spacing: 10) {
                    Text("\(drama.year)")
                    Text(drama.genre.resolved)
                    if drama.availability == .available {
                        Text(String(format: String(localized: "drama.episodes.format"), drama.episodes.count))
                        Text(String(format: String(localized: "drama.endings.format"), drama.endings.count))
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
                        Button { store.toggleFavorite(drama) } label: {
                            Image(systemName: store.isFavorite(drama) ? "heart.fill" : "heart")
                                .font(.title3).foregroundStyle(store.isFavorite(drama) ? .red : .primary)
                                .frame(width: 54, height: 54).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    episodeList
                } else {
                    Label("drama.coming.body", systemImage: "clock.badge.checkmark")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(18).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(PaperBackground()).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) { DramaPlayerView(drama: drama) }
    }

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("drama.episodes.title").font(.title3.bold())
            ForEach(drama.episodes) { episode in
                Button {
                    store.watch(drama: drama, episodeID: episode.id); showPlayer = true
                } label: {
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", episode.number)).font(.headline.monospacedDigit()).foregroundStyle(TaleForkTheme.coral)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title.resolved).font(.headline)
                            Text(episode.ending == nil ? "drama.interactive.episode" : "drama.ending.episode").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: store.run(for: drama).watchedEpisodeIDs.contains(episode.id) ? "checkmark.circle.fill" : "play.circle")
                            .foregroundStyle(store.run(for: drama).watchedEpisodeIDs.contains(episode.id) ? TaleForkTheme.mint : .secondary)
                    }.padding(14).foregroundStyle(.primary).background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
        }
    }
}
