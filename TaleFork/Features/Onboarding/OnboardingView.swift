import SwiftUI

struct OnboardingView: View {
    @Environment(ProgressStore.self) private var store
    @State private var page = 0

    var body: some View {
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            VStack(spacing: 0) {
                HStack {
                    BrandMark(size: 42)
                    Text("TaleFork")
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Spacer()
                    Text("\(page + 1) / 2")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, margin)
                .padding(.top, 14)
                .dynamicTypeSize(.xSmall ... .xxxLarge)

                TabView(selection: $page) {
                    introPage.tag(0)
                    pathPage.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? TaleForkTheme.coral : TaleForkTheme.mist)
                            .frame(width: index == page ? 28 : 8, height: 8)
                    }
                    Spacer()
                    Button {
                        if page < 1 {
                            page += 1
                        } else {
                            store.hasCompletedOnboarding = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(page == 1 ? "onboarding.begin" : "common.next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(TaleForkTheme.ink)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 50)
                        .background(TaleForkTheme.coral, in: Capsule())
                    }
                }
                .padding(.horizontal, margin)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
                .dynamicTypeSize(.xSmall ... .xxxLarge)
            }
        }
    }

    private var introPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(height: 220)
                .accessibilityHidden(true)
                Text("onboarding.title")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .fixedSize(horizontal: false, vertical: true)
                Text("onboarding.subtitle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
    }

    private var pathPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProgressPreview()
                    .frame(height: 250)
                Text("onboarding.path.title")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .fixedSize(horizontal: false, vertical: true)
                Text("onboarding.path.body")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
    }

}

private struct ProgressPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(1...4, id: \.self) { number in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(number <= 2 ? TaleForkTheme.coral : TaleForkTheme.mist.opacity(0.42))
                            .frame(width: 36, height: 36)
                        Image(systemName: number < 2 ? "checkmark" : (number == 2 ? "play.fill" : "lock.fill"))
                            .font(.caption.bold())
                            .foregroundStyle(number <= 2 ? TaleForkTheme.ink : TaleForkTheme.paper.opacity(0.55))
                    }
                    Text(String(format: String(localized: "player.episode.format"), number))
                        .font(.headline)
                        .foregroundStyle(TaleForkTheme.paper)
                    Spacer()
                    if number == 2 {
                        Text("discover.continue")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TaleForkTheme.coral)
                    }
                }
                .frame(maxHeight: .infinity)
                if number < 4 {
                    Divider().overlay(TaleForkTheme.paper.opacity(0.12))
                }
            }
        }
        .padding(24)
        .background(TaleForkTheme.ink, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityHidden(true)
    }
}
