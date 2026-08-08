import SwiftUI

enum TaleForkTheme {
    static let ink = Color(hex: "17152B")
    static let paper = Color(hex: "F7F3EA")
    static let coral = Color(hex: "FF6B5E")
    static let mint = Color(hex: "55D6BE")
    static let violet = Color(hex: "7868E6")
    static let mist = Color(hex: "E8E4F2")

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
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.78))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.44))
                path.addLine(to: CGPoint(x: size * 0.28, y: size * 0.22))
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.44))
                path.addLine(to: CGPoint(x: size * 0.72, y: size * 0.22))
            }
            .stroke(TaleForkTheme.coral, style: StrokeStyle(lineWidth: size * 0.105, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(TaleForkTheme.mint)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(y: size * 0.28)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("TaleFork"))
    }
}

struct StoryArtwork: View {
    let story: Story
    var height: CGFloat = 220

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(hex: story.palette.startHex), Color(hex: story.palette.endHex)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: max(width * 0.03, 8))
                    .frame(width: width * 0.72)
                    .offset(x: width * 0.3, y: -height * 0.25)
                Path { path in
                    path.move(to: CGPoint(x: width * 0.18, y: height * 0.82))
                    path.addCurve(
                        to: CGPoint(x: width * 0.78, y: height * 0.18),
                        control1: CGPoint(x: width * 0.34, y: height * 0.55),
                        control2: CGPoint(x: width * 0.58, y: height * 0.56)
                    )
                }
                .stroke(Color(hex: story.palette.accentHex).opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                Image(systemName: story.symbol)
                    .font(.system(size: min(width * 0.23, 74), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                VStack {
                    HStack {
                        Spacer()
                        Text("\(story.estimatedMinutes) MIN")
                            .font(.caption2.weight(.bold).monospaced())
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.22), in: Capsule())
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: TaleForkTheme.cardRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct SectionHeading: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(TaleForkTheme.coral)
                .textCase(.uppercase)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RouteDot: View {
    let isVisited: Bool
    let isCurrent: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isVisited ? TaleForkTheme.mint : TaleForkTheme.mist)
            if isCurrent {
                Circle()
                    .stroke(TaleForkTheme.coral, lineWidth: 3)
                    .padding(-4)
            }
        }
        .frame(width: 14, height: 14)
    }
}
