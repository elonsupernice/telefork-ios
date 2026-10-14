import SwiftUI

/// The app renders the server's offers and opens its returned page. Provider
/// session creation, authorization and recurring charges stay on the server.
struct HostedMembershipContent: View {
    @Environment(MembershipStore.self) private var membership
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page: HostedMembershipPage?
    @State private var requestTask: Task<Void, Never>?
    @State private var requestIDs: [String: String] = [:]
    @State private var errorMessage: String?
    @State private var isOpening = false
    @State private var confirmedCheckoutID: String?
    @State private var closingCheckoutID: String?
    let offers: [HostedMembershipOffer]
    let isPaywallVisible: Bool
    let checkoutTrigger: UUID

    var body: some View {
        MembershipGoldContent(benefitsAccessibilityIdentifier: "hosted-membership-content", isPaywallVisible: isPaywallVisible && page == nil,
                              usesFullWidthCheckoutFooter: true) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { offerCards }
                    .padding(.horizontal, 20)
            } else {
                HStack(alignment: .top, spacing: 10) { offerCards }
                    .padding(.horizontal, 20)
            }
            VStack(spacing: 0) {
                if let deadline = membership.promotionDeadline {
                    MembershipCountdownBanner(expiresAt: deadline)
                        .accessibilityIdentifier("membership-promotion-countdown")
                        .padding(.horizontal, 20)
                }
                HStack(spacing: 0) {
                    checkoutSpace.frame(width: 20)
                    MembershipOpenButton(isBusy: isOpening, isEnabled: membership.selectedHostedOffer != nil,
                                         isVisible: isPaywallVisible && page == nil, action: beginCheckout)
                        .accessibilityIdentifier("hosted-membership-open")
                    checkoutSpace.frame(width: 20)
                }
                .padding(.top, 8)
                checkoutSpace.frame(height: 8)
                MembershipPolicyLinks(purchaseDetails: membership.selectedHostedOffer?.trailDesc ?? "")
                    .padding(.horizontal, 20)
                    .background { checkoutSpace }
            }
            .padding(.top, 8)
        }
        .onChange(of: checkoutTrigger) { _, _ in beginCheckout() }
        .fullScreenCover(item: $page, onDismiss: pageClosed) { page in
            HostedPageView(url: page.payDetail, checkoutID: page.checkoutID,
                           onConfirmed: { confirmedCheckoutID = page.checkoutID })
        }
        .alert("membership.purchase.status", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.done") { errorMessage = nil }
        } message: {
            if let errorMessage { Text(verbatim: errorMessage) }
        }
        .onDisappear {
            if page == nil {
                requestTask?.cancel()
                membership.setCheckoutPresented(false)
            }
        }
    }

    private var offerCards: some View {
        ForEach(offers) { offer in
            MembershipPlanCard(title: offer.title, price: offer.displayPrice, detail: offer.vipDesc,
                               isSelected: membership.selectedHostedOffer?.id == offer.id,
                               isHorizontal: offers.count == 1) {
                membership.selectHostedOffer(offer)
            }
            .frame(maxWidth: .infinity)
            .disabled(isOpening)
            .accessibilityIdentifier("hosted-offer-\(offer.id)")
        }
    }

    private var checkoutSpace: some View {
        // Blank footer space shares the CTA action but never overlaps the
        // main button, so one tap cannot submit the same request twice.
        Button(action: beginCheckout) {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOpening || membership.selectedHostedOffer == nil)
        .accessibilityHidden(true)
    }

    private func beginCheckout() {
        guard !isOpening, page == nil, let offer = membership.selectedHostedOffer else { return }
        // A retry of the same offer reuses the request ID, preventing duplicate
        // orders when a response is lost. Opening the paywall never orders.
        let requestID = requestIDs[offer.id] ?? UUID().uuidString
        requestIDs[offer.id] = requestID
        isOpening = true
        membership.setCheckoutPresented(true)
        requestTask = Task {
            defer {
                isOpening = false
                if page == nil { membership.setCheckoutPresented(false) }
            }
            do {
                let response = try await TaleForkService.shared.hostedMembershipPage(
                    offerID: offer.id, clientRequestID: requestID)
                guard !Task.isCancelled else { return }
                confirmedCheckoutID = nil
                closingCheckoutID = response.checkoutID
                page = response
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func pageClosed() {
        requestIDs.removeAll()
        membership.setCheckoutPresented(false)
        let checkoutID = closingCheckoutID
        closingCheckoutID = nil
        if let confirmedCheckoutID {
            self.confirmedCheckoutID = nil
            membership.completeHostedCheckout(confirmedCheckoutID)
            return
        }
        Task {
            // Also cover a user closing H5 just as the callback arrives.
            if let checkoutID, await membership.confirmHostedMembership() {
                membership.completeHostedCheckout(checkoutID)
            } else {
                membership.preparePaywall()
                await membership.refreshEntitlements()
            }
        }
    }
}
