import SwiftUI

struct MembershipCountdownBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let expiresAt: Date
    var isCashier = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = MembershipCountdown(expiresAt: expiresAt)
            let label = LocalizedStringKey(countdown.remainingSeconds(at: context.date) > 0
                ? "membership.promotion.reservation" : "membership.promotion.expired")
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 4) {
                        Text(label).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        timeRemaining(countdown.timeText(at: context.date))
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(label).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        timeRemaining(countdown.timeText(at: context.date))
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(isCashier ? Color.secondary : MembershipStyle.buttonInk)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isCashier ? Color.white : MembershipStyle.gold)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("membership-reservation-countdown")
        }
    }

    private func timeRemaining(_ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "hourglass").accessibilityHidden(true)
            Text(value).monospacedDigit().fontWeight(.semibold).fixedSize()
                .foregroundStyle(isCashier ? Color.secondary : MembershipStyle.countdownAccent)
        }
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
