import StoreKit
import SwiftUI

// THESIS: A premium membership presentation backed by the current server configuration.
// OWN-WORLD: Deep brown, golden reservation strip, original bronze crown and real posters.
// STORY: Review access, browse, choose an existing plan, open the existing checkout.
// FIRST VIEWPORT: Benefits/carousel above a fixed real-price plan dock and one action.
// FORM: User-pinned bc08e3c6 composition; no invented prices, discounts or benefits.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
struct MembershipPaywallView: View {
    @Environment(MembershipStore.self) private var membership
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @Environment(\.scenePhase) private var scenePhase
    @State private var purchaseMessage: LocalizedStringKey?
    @State private var isShowingRetention = false
    @State private var hostedCheckoutTrigger = UUID()
    @State private var isPurchasingFromRetention = false

    var body: some View {
        NavigationStack {
            ZStack {
                MembershipStyle.background.ignoresSafeArea()
                LinearGradient(colors: [Color(hex: "A95512").opacity(0.8), MembershipStyle.background], startPoint: .topLeading, endPoint: .center)
                    .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)

                Group {
                    if membership.paywall.isLoading {
                        ProgressView("membership.presentation.loading")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = membership.paywall.errorMessage {
                        VStack(spacing: 16) {
                            Text(verbatim: error).multilineTextAlignment(.center)
                                .accessibilityIdentifier("membership-load-error")
                            Button("common.retry") { membership.preparePaywall() }
                                .frame(minWidth: 100, minHeight: 44)
                                .accessibilityIdentifier("membership-load-retry")
                        }.padding(24)
                    } else if let snapshot = membership.paywall.snapshot {
                        switch snapshot.configuration.route {
                        case .appStore: appleCheckoutContent
                        case .hostedPage:
                            HostedMembershipContent(offers: snapshot.offers, isPaywallVisible: !isShowingRetention,
                                                    checkoutTrigger: hostedCheckoutTrigger)
                        }
                    }
                }
                .opacity(isShowingRetention ? 0 : 1)
                .allowsHitTesting(!isShowingRetention)
                .accessibilityHidden(isShowingRetention)

                if isShowingRetention {
                    MembershipRetentionView(
                        planTitle: retentionPlanTitle,
                        planPrice: retentionPlanPrice,
                        reservationDeadline: membership.promotionDeadline,
                        isPurchasing: isPurchasingFromRetention,
                        onContinue: continueFromRetention
                    )
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let deadline = membership.promotionDeadline {
                    MembershipCountdownBanner(expiresAt: deadline)
                        .accessibilityIdentifier("membership-promotion-countdown")
                }
            }
            .navigationTitle("membership.navigation.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MembershipStyle.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .cancellationAction) {
                        if !isShowingRetention { backButton }
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .confirmationAction) {
                        if isShowingRetention { retentionCloseButton }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        if !isShowingRetention { backButton }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isShowingRetention { retentionCloseButton }
                    }
                }
            }
        }
        .tint(MembershipStyle.gold)
        .preferredColorScheme(.dark)
        // Every paywall entry uses fullScreenCover. The explicit back action
        // shows retention within this same screen, preserving plan selection.
        .interactiveDismissDisabled()
        .membershipCaptureProtected(allowed: membership.membershipScreenshotsAllowed)
        .task {
            membership.beginPaywallFlow()
            membership.preparePaywall()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !membership.isPresentingCheckout && !isPurchasingFromRetention {
                membership.preparePaywall()
            }
        }
        .onChange(of: membership.isSubscribed) { _, isSubscribed in
            guard isSubscribed else { return }
            closePaywall()
        }
        .alert("membership.purchase.status", isPresented: purchaseMessageBinding) {
            Button("common.done") { purchaseMessage = nil }
        } message: {
            if let purchaseMessage { Text(purchaseMessage) }
        }
    }

    private var backButton: some View {
        Button(action: handleBack) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.regular))
                .foregroundStyle(MembershipStyle.secondaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("common.back"))
        .accessibilityIdentifier("membership-close")
    }

    private var retentionCloseButton: some View {
        Button(action: closePaywall) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MembershipStyle.secondaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPurchasingFromRetention)
        .accessibilityLabel(Text("common.close"))
        .accessibilityIdentifier("membership-retention-close")
    }

    private var retentionPlanTitle: String {
        if membership.paywall.snapshot?.configuration.route == .hostedPage {
            return membership.selectedHostedOffer?.title ?? ""
        }
        return String(localized: String.LocalizationValue(MembershipAccess.periodKey(for: membership.appleProduct?.id ?? "")))
    }

    private var retentionPlanPrice: String {
        if membership.paywall.snapshot?.configuration.route == .hostedPage {
            return membership.selectedHostedOffer?.displayPrice ?? ""
        }
        return membership.appleProduct?.displayPrice ?? ""
    }

    private func handleBack() {
        if membership.isSubscribed {
            closePaywall()
        } else {
            isShowingRetention = true
        }
    }

    private func continueFromRetention() {
        guard !isPurchasingFromRetention else { return }
        if membership.paywall.snapshot?.configuration.route == .hostedPage {
            isShowingRetention = false
            hostedCheckoutTrigger = UUID()
            return
        }
        isPurchasingFromRetention = true
        membership.setCheckoutPresented(true)
        Task {
            defer { isPurchasingFromRetention = false; membership.setCheckoutPresented(false) }
            do {
                guard let product = membership.appleProduct else { return }
                let options: Set<Product.PurchaseOption> = membership.appleAccountToken.map { [.appAccountToken($0)] } ?? []
                let result = try await purchase(product, options: options)
                switch result {
                case .success(let verification):
                    guard case .verified(let transaction) = verification else {
                        purchaseMessage = "membership.purchase.unverified"
                        return
                    }
                    await membership.processVerifiedTransaction(transaction, signedTransaction: verification.jwsRepresentation)
                case .pending: purchaseMessage = "membership.purchase.pending"
                case .userCancelled: break
                @unknown default: purchaseMessage = "membership.purchase.failed"
                }
            } catch { purchaseMessage = "membership.purchase.failed" }
        }
    }

    private func closePaywall() {
        membership.endPaywallFlow()
        dismiss()
    }

    private var appleCheckoutContent: some View {
        AppleMembershipContent(isPaywallVisible: !isShowingRetention) { purchaseMessage = $0 }
    }

    private var purchaseMessageBinding: Binding<Bool> {
        Binding(
            get: { purchaseMessage != nil },
            set: { if !$0 { purchaseMessage = nil } }
        )
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringKey) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
    }
}

private struct MembershipRetentionView: View {
    @Environment(CatalogStore.self) private var catalog
    let planTitle: String
    let planPrice: String
    let reservationDeadline: Date?
    let isPurchasing: Bool
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    MembershipShowcase(dramas: catalog.dramas, autoplay: true)
                    Text("membership.retention.title")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 6) {
                        Text(planTitle).font(.headline)
                            .accessibilityIdentifier("membership-retention-plan-title")
                        if !planPrice.isEmpty {
                            Text(planPrice).font(.title2.bold())
                        }
                        if let reservationDeadline {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(MembershipCountdown(expiresAt: reservationDeadline).timeText(at: context.date))
                                    .font(.system(.title3, design: .monospaced, weight: .bold))
                                    .accessibilityLabel("membership.countdown.accessibility")
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(MembershipStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                    MembershipOpenButton(isBusy: isPurchasing, isEnabled: !planPrice.isEmpty, isVisible: true, isRetention: true, action: onContinue)
                    .accessibilityIdentifier("membership-retention-continue")
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("membership-retention-scroll")
        }
        .foregroundStyle(MembershipStyle.title)
    }
}
