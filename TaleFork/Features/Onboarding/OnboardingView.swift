import SwiftUI

struct OnboardingView: View {
    @Environment(ProgressStore.self) private var store
    @State private var page = 0
    @State private var selectedGenres: Set<String> = []

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            VStack(spacing: 0) {
                HStack {
                    BrandMark(size: 42)
                    Text("TaleFork")
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Spacer()
                    Text("\(page + 1) / 3")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, margin)
                .padding(.top, 14)

                TabView(selection: $page) {
                    introPage.tag(0)
                    pathPage.tag(1)
                    preferencePage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? TaleForkTheme.coral : TaleForkTheme.mist)
                            .frame(width: index == page ? 28 : 8, height: 8)
                    }
                    Spacer()
                    Button {
                        if page < 2 {
                            page += 1
                        } else {
                            store.preferences.preferredGenres = selectedGenres
                            store.hasCompletedOnboarding = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(page == 2 ? "onboarding.begin" : "common.next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 50)
                        .background(TaleForkTheme.coral, in: Capsule())
                    }
                }
                .padding(.horizontal, margin)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
            }
        }
    }

    private var introPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 12)
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [TaleForkTheme.violet, TaleForkTheme.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(height: 300)
            .accessibilityHidden(true)
            Text("onboarding.title")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
            Text("onboarding.subtitle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var pathPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            RoutePreview()
                .frame(height: 290)
            Text("onboarding.path.title")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
            Text("onboarding.path.body")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var preferencePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("onboarding.genre.title")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
            Text("onboarding.genre.body")
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 12)], spacing: 12) {
                genreChip(id: "mystery", title: "genre.mystery", symbol: "moon.stars")
                genreChip(id: "speculative", title: "genre.speculative", symbol: "sparkles")
                genreChip(id: "emotional", title: "genre.emotional", symbol: "heart.text.square")
                genreChip(id: "coastal", title: "genre.coastal", symbol: "water.waves")
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func genreChip(id: String, title: LocalizedStringKey, symbol: String) -> some View {
        let selected = selectedGenres.contains(id)
        return Button {
            if selected { selectedGenres.remove(id) } else { selectedGenres.insert(id) }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                HStack {
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                }
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(selected ? TaleForkTheme.violet : TaleForkTheme.mist.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RoutePreview: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(TaleForkTheme.ink)
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.78))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.52))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.25, y: proxy.size.height * 0.25))
                    path.move(to: CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.52))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.76, y: proxy.size.height * 0.25))
                }
                .stroke(TaleForkTheme.coral, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                ForEach(Array([
                    CGPoint(x: 0.5, y: 0.78), CGPoint(x: 0.5, y: 0.52),
                    CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.76, y: 0.25)
                ].enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(point.x == 0.76 ? TaleForkTheme.coral : TaleForkTheme.paper)
                        .frame(width: 22, height: 22)
                        .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
