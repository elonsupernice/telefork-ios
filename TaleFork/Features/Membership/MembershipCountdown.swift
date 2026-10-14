import SwiftUI

struct MembershipCountdownBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let expiresAt: Date
    private let labelInk = Color(hex: "351009")

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = MembershipCountdown(expiresAt: expiresAt)
            let seconds = countdown.remainingSeconds(at: context.date)
            let label = LocalizedStringKey(seconds > 0
                ? "membership.promotion.badge" : "membership.promotion.expired")
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(label).multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        timeRemaining(seconds)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(label).multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        timeRemaining(seconds)
                    }
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(labelInk)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .background {
                MembershipCountdownBubble()
                    .fill(LinearGradient(colors: [Color(hex: "E96A3C"), Color(hex: "F14660")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { MembershipCountdownBubble().stroke(.white.opacity(0.95), lineWidth: 1.2) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(seconds > 0 ? "membership.promotion.reservation" : "membership.promotion.expired"))
            .accessibilityValue(Text(verbatim: countdown.timeText(at: context.date)))
            .accessibilityIdentifier("membership-reservation-countdown")
        }
    }

    private func timeRemaining(_ seconds: Int) -> some View {
        HStack(spacing: 3) {
            Text(String(format: "%02d", seconds / 3600)).monospacedDigit()
            Text("membership.countdown.hour").font(.caption2).foregroundStyle(labelInk)
            Text(String(format: "%02d", seconds / 60 % 60)).monospacedDigit()
            Text("membership.countdown.minute").font(.caption2).foregroundStyle(labelInk)
            Text(String(format: "%02d", seconds % 60)).monospacedDigit()
            Text("membership.countdown.second").font(.caption2).foregroundStyle(labelInk)
        }
        .font(.subheadline.bold())
        .foregroundStyle(.white)
        .fixedSize()
    }
}

private struct MembershipCountdownBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let bottom = rect.maxY - 6
        let radius: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: bottom), control: CGPoint(x: rect.maxX, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX + 26, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX + 20, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 14, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: bottom - radius), control: CGPoint(x: rect.minX, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct MembershipCountdown: Sendable {
    let expiresAt: Date
    static let reservationDuration = 180

    func remainingSeconds(at now: Date) -> Int {
        max(0, Int(ceil(expiresAt.timeIntervalSince(now))))
    }

    func timeText(at now: Date) -> String {
        let seconds = remainingSeconds(at: now)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
