import SwiftUI

struct VaultView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @State private var selection = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(eyebrow: "vault.eyebrow", title: "vault.title")
                    Picker("vault.segment", selection: $selection) {
                        Text("vault.history").tag(0)
                        Text("vault.favorites").tag(1)
                    }.pickerStyle(.segmented)

                    if selection == 0 { historyContent } else { favoriteContent }
                }
                .padding(.horizontal, TaleForkTheme.horizontalMargin(for: proxy.size.width)).padding(.vertical, 20)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.background(PaperBackground())
        }.navigationTitle("tab.vault").navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var historyContent: some View {
        if store.history.isEmpty { emptyState("clock.arrow.circlepath", "vault.history.empty.title", "vault.history.empty.body") }
        else {
            LazyVStack(spacing: 14) {
                ForEach(store.history) { entry in
                    if let drama = catalog.drama(id: entry.dramaID) {
                        NavigationLink(value: drama) { libraryRow(drama: drama, entry: entry) }.buttonStyle(.plain)
                    }
                }
            }.navigationDestination(for: Drama.self) { DramaDetailView(drama: $0) }
        }
    }

    @ViewBuilder private var favoriteContent: some View {
        let source = catalog.dramas.isEmpty ? DramaLibrary.dramas : catalog.dramas
        let dramas = source.filter { store.favoriteDramaIDs.contains($0.id) }
        if dramas.isEmpty { emptyState("heart", "vault.favorites.empty.title", "vault.favorites.empty.body") }
        else {
            LazyVStack(spacing: 14) {
                ForEach(dramas) { drama in
                    NavigationLink(value: drama) { libraryRow(drama: drama, entry: nil) }.buttonStyle(.plain)
                }
            }.navigationDestination(for: Drama.self) { DramaDetailView(drama: $0) }
        }
    }

    private func libraryRow(drama: Drama, entry: WatchHistoryEntry?) -> some View {
        HStack(spacing: 14) {
            BundleImage(name: drama.posterImageName, remoteURL: drama.coverURL).scaledToFill().frame(width: 84, height: 112).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text(drama.title.resolved).font(.headline)
                Text(drama.genre.resolved).font(.caption).foregroundStyle(TaleForkTheme.coral)
                if let entry, let episode = drama.episode(id: entry.episodeID) {
                    Text(String(format: String(localized: "vault.last.watched.format"), episode.number, episode.title.resolved)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }.padding(12).foregroundStyle(.primary).background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
    }

    private func emptyState(_ symbol: String, _ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40)).foregroundStyle(TaleForkTheme.violet)
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 44).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }
}
