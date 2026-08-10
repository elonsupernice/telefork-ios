import SwiftUI
import UIKit

enum TaleForkTheme {
    static let ink = Color(hex: "091018")
    static let paper = Color(hex: "F4F1EA")
    static let coral = Color(hex: "E6A84C")
    static let accentText = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 230 / 255, green: 168 / 255, blue: 76 / 255, alpha: 1)
        }
        return UIColor(red: 138 / 255, green: 78 / 255, blue: 0, alpha: 1)
    })
    static let mint = Color(hex: "59C4BE")
    static let violet = Color(hex: "6570C5")
    static let mist = Color(hex: "DEE6E9")

    static let cardRadius: CGFloat = 24

    static func horizontalMargin(for width: CGFloat) -> CGFloat {
        min(max(width * 0.052, 16), 28)
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)
        let red, green, blue, alpha: UInt64
        switch value.count {
        case 8:
            red = integer >> 24
            green = integer >> 16 & 0xFF
            blue = integer >> 8 & 0xFF
            alpha = integer & 0xFF
        default:
            red = integer >> 16
            green = integer >> 8 & 0xFF
            blue = integer & 0xFF
            alpha = 0xFF
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

struct PaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? TaleForkTheme.ink : TaleForkTheme.paper)
                .ignoresSafeArea()
            Circle()
                .fill(TaleForkTheme.violet.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 2)
                .offset(x: 170, y: -330)
            Circle()
                .fill(TaleForkTheme.mint.opacity(colorScheme == .dark ? 0.12 : 0.1))
                .frame(width: 240, height: 240)
                .offset(x: -170, y: 350)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct BrandMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(colorScheme == .dark ? Color(hex: "26223F") : TaleForkTheme.ink)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.14 : 0), lineWidth: 1)
                }
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(TaleForkTheme.coral)
                .offset(x: size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("TaleFork"))
    }
}

struct DramaPoster: View {
    let drama: Drama
    var height: CGFloat = 220

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BundleImage(name: drama.posterImageName, remoteURL: drama.coverURL)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: height)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                VStack {
                    HStack {
                        Spacer()
                        Text(drama.availability == .available ? String(format: String(localized: "drama.episodes.format"), drama.episodes.count) : String(localized: "drama.coming.soon"))
                            .font(.caption2.weight(.bold).monospaced())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.22), in: Capsule())
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(drama.title.resolved)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: TaleForkTheme.cardRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct BundleImage: View {
    let name: String
    var remoteURL: URL? = nil

    @ViewBuilder
    var body: some View {
        if let remoteURL {
            AsyncImage(url: remoteURL, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case let .success(image): image.resizable()
                case .failure: artworkFallback
                case .empty: artworkFallback.overlay { ProgressView().tint(.white) }
                @unknown default: artworkFallback
                }
            }
        } else if let url = Bundle.main.url(forResource: name, withExtension: nil), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable()
        } else {
            artworkFallback
        }
    }

    private var artworkFallback: some View {
        Rectangle().fill(LinearGradient(colors: [TaleForkTheme.ink, TaleForkTheme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.35)) }
    }
}

struct SectionHeading: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(TaleForkTheme.accentText)
                .textCase(.uppercase)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
