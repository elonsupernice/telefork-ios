import SwiftUI

struct OnboardingView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinished: (() -> Void)?
    @State private var page = 0
    private let pageCount = 4

    private let cinema = Color(hex: "190D12")
    private let titleGold = Color(hex: "FFE4B9")

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                BrandMark(size: 30)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("TaleFork")
                        .font(.system(.title3, design: .rounded, weight: .black))
                }
                Spacer(minLength: 8)
                Text("\(page + 1) / \(pageCount)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .accessibilityIdentifier("onboarding-page-count")
            }
            .foregroundStyle(titleGold)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

            TabView(selection: $page) {
                qualityPage.tag(0)
                posterPage(
                    image: "OnboardingEscape",
                    title: "onboarding.finale.title", body: "onboarding.finale.body",
                    label: "onboarding.finale.accessibility",
                    artworkID: "onboarding-story-artwork", scrollID: "onboarding-story-scroll"
                ).tag(1)
                posterPage(
                    image: "OnboardingDaily",
                    title: "onboarding.path.title", body: "onboarding.path.body",
                    label: "onboarding.ending.accessibility",
                    artworkID: "onboarding-ending-artwork", scrollID: "onboarding-ending-scroll"
                ).tag(2)
                posterPage(
                    image: "OnboardingImmersive",
                    title: "onboarding.suspense.title", body: "onboarding.suspense.body",
                    label: "onboarding.emotion.accessibility",
                    artworkID: "onboarding-finale-artwork", scrollID: "onboarding-finale-scroll"
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(cinema.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await catalog.load() }
    }

    private var qualityPage: some View {
        GeometryReader { canvas in
            ScrollView {
                VStack(spacing: 12) {
                    heading("onboarding.title")
                    OnboardingQualityArtwork(
                        photoHeight: dynamicTypeSize.isAccessibilitySize
                            ? 340 : max(260, min(400, canvas.size.height - 280))
                    )
                    .padding(.horizontal, 24)
                    supportingCopy("onboarding.subtitle")
                }
                .padding(.top, 14)
                .padding(.bottom, 12)
                .frame(minHeight: canvas.size.height)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("onboarding-intro-scroll")
        }
    }

    /// All artwork is bundled. Catalog loading remains separate for registration and the next screen.
    private func posterPage(
        image: String, title: LocalizedStringKey, body: LocalizedStringKey,
        label: LocalizedStringKey, artworkID: String, scrollID: String
    ) -> some View {
        GeometryReader { canvas in
            ScrollView {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 24) {
                        heading(title)
                        posterArtwork(image, size: CGSize(width: canvas.size.width, height: 320))
                            .frame(height: 320)
                            .accessibilityLabel(Text(label))
                            .accessibilityIdentifier(artworkID)
                        supportingCopy(body)
                    }
                    .padding(.vertical, 20)
                } else {
                    ZStack {
                        posterArtwork(image, size: canvas.size)
                            .accessibilityLabel(Text(label))
                            .accessibilityIdentifier(artworkID)
                        LinearGradient(
                            stops: [.init(color: cinema.opacity(0.94), location: 0),
                                    .init(color: cinema.opacity(0.4), location: 0.18),
                                    .init(color: .clear, location: 0.35),
                                    .init(color: .clear, location: 0.68),
                                    .init(color: cinema.opacity(0.96), location: 0.91),
                                    .init(color: cinema, location: 1)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .accessibilityHidden(true)
                        VStack(spacing: 20) {
                            heading(title)
                            Spacer(minLength: 200)
                            supportingCopy(body)
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                    }
                    .frame(minHeight: canvas.size.height)
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(scrollID)
        }
    }

    private func posterArtwork(_ name: String, size: CGSize) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityElement(children: .ignore)
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle,
                          design: .rounded, weight: .black))
            .lineSpacing(5)
            .multilineTextAlignment(.center)
            .foregroundStyle(titleGold)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isHeader)
    }

    private func supportingCopy(_ body: LocalizedStringKey) -> some View {
        Text(body)
            .font(.body)
            .lineSpacing(5)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(hex: "F4DDC5"))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
    }

    private var actionTitle: LocalizedStringKey {
        switch page {
        case 0: "onboarding.next.story"
        case 1: "onboarding.next.suspense"
        case 2: "onboarding.next.story"
        default: "onboarding.begin"
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? titleGold : titleGold.opacity(0.25))
                        .frame(width: index == page ? 28 : 8, height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(page + 1) / \(pageCount)"))
            Button(action: advance) {
                HStack(spacing: 12) {
                    Text(actionTitle)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Image(systemName: "arrow.right") }
                }
                .font(.headline)
                .foregroundStyle(Color(hex: "2E170F"))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [titleGold, TaleForkTheme.coral],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .accessibilityIdentifier(page == pageCount - 1 ? "onboarding-begin" : "onboarding-next")
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(cinema)
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(reduceMotion || store.preferences.reduceDecorativeMotion ? nil : .easeOut(duration: 0.25)) {
                page += 1
            }
        } else {
            store.hasCompletedOnboarding = true
            onFinished?()
        }
    }
}
