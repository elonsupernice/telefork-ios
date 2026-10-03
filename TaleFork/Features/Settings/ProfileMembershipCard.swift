import SwiftUI

struct ProfileMembershipCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let isSubscribed: Bool
    let onOpenMembership: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    heading
                    Spacer(minLength: 8)
                    openButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    heading
                    openButton
                }
            }
            Divider().overlay(Color(hex: "6E471B").opacity(0.25))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                      alignment: .leading, spacing: 12) {
                benefit("membership.presentation.feature.watch", symbol: "play.rectangle.fill")
                benefit("membership.presentation.feature.episodes", symbol: "rectangle.stack.fill")
                benefit("membership.presentation.feature.library", symbol: "bookmark.fill")
                benefit("membership.presentation.feature.notes", symbol: "note.text")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color(hex: "301B08"))
        .background(
            LinearGradient(colors: [Color(hex: "FFE9BD"), Color(hex: "E8B24F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-membership-card")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image("MembershipCrownGold")
                    .resizable().scaledToFit().frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text("TaleFork VIP").font(.title3.bold())
            }
            if isSubscribed {
                Text("settings.membership.active")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var openButton: some View {
        Button(action: onOpenMembership) {
            Text(isSubscribed ? "settings.membership.manage" : "settings.membership.join")
                .font(.subheadline.bold())
                .foregroundStyle(Color(hex: "FFE6BE"))
                .padding(.horizontal, 18)
                .frame(minWidth: 88, minHeight: 48)
                .background(Color(hex: "382315"), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-membership-open")
    }

    private func benefit(_ key: LocalizedStringKey, symbol: String) -> some View {
        Label(key, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }
}
