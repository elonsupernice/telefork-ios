import SwiftUI

/// A bundled illustration, not a player or a quality selector.
struct OnboardingQualityArtwork: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let photoHeight: CGFloat

    private let gold = Color(hex: "FFE4B9")
    private let panel = Color(hex: "291117")

    var body: some View {
        VStack(spacing: -18) {
            GeometryReader { photo in
                Image("OnboardingHDComparison")
                    .resizable()
                    .scaledToFill()
                    .frame(width: photo.size.width, height: photo.size.height)
                    .clipped()
                    .overlay {
                        Rectangle()
                            .fill(gold.opacity(0.85))
                            .frame(width: 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        Text(verbatim: "1080P")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(panel, in: RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(gold.opacity(0.45), lineWidth: 1)
                    }
            }
            .frame(height: photoHeight)
            .padding(.horizontal, 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("onboarding.quality.accessibility"))
            .accessibilityIdentifier("onboarding-hd-comparison")

            VStack(spacing: 14) {
                Text("onboarding.quality.title")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(gold)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    qualityLabel("540P", highlighted: false)
                    qualityLabel("720P", highlighted: false)
                    qualityLabel("1080P", highlighted: true)
                }
            }
            .padding(16)
            .background(panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(gold.opacity(0.45), lineWidth: 1)
            }
        }
    }

    private func qualityLabel(_ title: String, highlighted: Bool) -> some View {
        HStack(spacing: 5) {
            Text(verbatim: title)
            if highlighted {
                Image(systemName: "checkmark.seal.fill")
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(highlighted ? gold : Color(hex: "F4DDC5"))
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(highlighted ? gold.opacity(0.1) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(gold.opacity(highlighted ? 0.8 : 0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding-quality-\(title)")
    }
}
