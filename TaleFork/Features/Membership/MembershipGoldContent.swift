import SwiftUI

/// Membership layout using real StoreKit plans and existing playback controls.
struct MembershipGoldContent<Plans: View>: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var benefitsAccessibilityIdentifier = "membership-benefits-scroll"
    var isPaywallVisible = true
    var usesFullWidthCheckoutFooter = false
    @ViewBuilder let plans: () -> Plans

    var body: some View {
        GeometryReader { geometry in
            // Reclaim a little of the decorative bottom gap without putting
            // legal controls into the home indicator's gesture area.
            let dockBottomAdjustment = dynamicTypeSize.isAccessibilitySize ? 0 : min(10, max(0, geometry.safeAreaInsets.bottom - 24))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Real dramas lead the first viewport; supporting benefits
                    // must not push their carousel below the purchase dock.
                    MembershipShowcase(dramas: catalog.dramas, autoplay: true,
                                               isPlaybackActive: isPaywallVisible,
                                               previewIdentifier: "membership-paywall-video")
                    MembershipBenefitsCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 12 : 20)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(benefitsAccessibilityIdentifier)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Large text keeps both sections independently reachable rather
                // than letting a tall fixed dock hide the entire carousel.
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("membership.presentation.plans.title")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, usesFullWidthCheckoutFooter ? 20 : 0)
                        plans()
                    }
                    .padding(.horizontal, usesFullWidthCheckoutFooter ? 0 : 20)
                    .padding(.top, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("membership-plans-scroll")
                .frame(height: dynamicTypeSize.isAccessibilitySize ? geometry.size.height * 0.55 : nil)
                .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : 345)
                .fixedSize(horizontal: false, vertical: !dynamicTypeSize.isAccessibilitySize)
                .background(MembershipStyle.background, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
                .overlay(alignment: .top) {
                    Rectangle().fill(MembershipStyle.gold.opacity(0.4)).frame(height: 1)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, -dockBottomAdjustment)
            }
        }
        .foregroundStyle(MembershipStyle.title)
        .task { await catalog.load() }
    }
}

private struct MembershipBenefitsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("membership.gold.benefits")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if dynamicTypeSize.isAccessibilitySize {
                    benefit("membership.presentation.feature.watch")
                    benefit("membership.presentation.feature.hd")
                    benefit("membership.presentation.feature.early")
                } else {
                    HStack(spacing: 12) {
                        benefit("membership.presentation.feature.watch")
                        benefit("membership.presentation.feature.hd")
                        benefit("membership.presentation.feature.early")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Image("MembershipCrownGold")
                    .resizable().scaledToFit()
                    .frame(width: 52, height: 52)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [MembershipStyle.panel, MembershipStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("membership-benefits-card")
    }

    private func benefit(_ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "checkmark")
                .accessibilityHidden(true)
            Text(key).fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption2)
        .foregroundStyle(MembershipStyle.secondaryText)
    }
}

struct MembershipOpenButton: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOnScreen = false
    let isBusy: Bool
    let isEnabled: Bool
    let isVisible: Bool
    var isRetention = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The reference's whole capsule breathes, while this transparent
            // full-width label keeps edge taps and accessibility bounds stable.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: isRetention ? 72 : 58)
                .overlay {
                    HStack(spacing: 10) {
                        if isBusy { ProgressView().tint(MembershipStyle.buttonInk) }
                        Text(LocalizedStringKey(isRetention ? "membership.retention.continue" : "membership.presentation.open"))
                            .font(isRetention ? .title2.bold() : .title3.bold())
                        Image(systemName: "arrow.right")
                            .font(isRetention ? .title2.weight(.semibold) : .title3.weight(.semibold))
                    }
                    .foregroundStyle(MembershipStyle.buttonInk)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: isRetention ? 72 : 58)
                    .background {
                        Capsule().fill(LinearGradient(colors: [MembershipStyle.lightGold, MembershipStyle.gold],
                                                     startPoint: .leading, endPoint: .trailing))
                    }
                    .phaseAnimator(shouldBreathe ? [false, true] : [true]) { surface, expanded in
                        surface
                            .scaleEffect(shouldBreathe && !expanded ? 0.80 : 1)
                            .brightness(shouldBreathe && expanded ? 0.06 : 0)
                            .shadow(color: MembershipStyle.gold.opacity(shouldBreathe && expanded ? 0.55 : 0.12),
                                    radius: shouldBreathe && expanded ? 22 : 6, x: 0, y: 4)
                    } animation: { _ in shouldBreathe ? .easeInOut(duration: 0.8) : nil }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(isRetention ? "membership.retention.continue" : "membership.presentation.open")))
        .disabled(!isEnabled || isBusy)
        .opacity(isEnabled && !isBusy ? 1 : 0.65)
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
    }

    private var shouldBreathe: Bool {
        isOnScreen && isVisible && isEnabled && !isBusy && scenePhase == .active
            && !reduceMotion && !progress.preferences.reduceDecorativeMotion
    }
}

struct MembershipPolicyLinks: View {
    var purchaseDetails: String? = nil
    var restoreAction: (() -> Void)? = nil
    var isRestoring = false
    var isRestoreDisabled = false

    var body: some View {
        HStack(spacing: 8) {
            if let restoreAction {
                Button(action: restoreAction) {
                    HStack(spacing: 4) {
                        if isRestoring { ProgressView() }
                        Text("membership.apple.restore")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .disabled(isRestoreDisabled)
                .accessibilityIdentifier("apple-membership-restore")
            } else if let purchaseDetails {
                NavigationLink {
                    MembershipPurchaseDetailsView(details: purchaseDetails)
                } label: {
                    Text("membership.purchase.details")
                        .fixedSize()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("membership-purchase-details")
            }
            NavigationLink { LocalLegalView(document: .terms) } label: {
                Text("settings.terms")
                    .fixedSize()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("membership-terms-link")
            NavigationLink { LocalLegalView(document: .privacy) } label: {
                Text("membership.privacy.short")
                    .fixedSize()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("membership-privacy-link")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MembershipStyle.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

private struct MembershipPurchaseDetailsView: View {
    let details: String

    var body: some View {
        ScrollView {
            if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("membership.purchase.details.empty", systemImage: "doc.text")
            } else {
                Text(verbatim: details)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("membership-purchase-details-content")
                    .padding(20)
            }
        }
        .background(MembershipStyle.background)
        .foregroundStyle(MembershipStyle.title)
        .navigationTitle("membership.purchase.details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
