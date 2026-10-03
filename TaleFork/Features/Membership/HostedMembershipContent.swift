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
    let offers: [HostedMembershipOffer]
    let isPaywallVisible: Bool
    let checkoutTrigger: UUID

    var body: some View {
        MembershipGoldContent(benefitsAccessibilityIdentifier: "hosted-membership-content", isPaywallVisible: isPaywallVisible && page == nil) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { offerCards }
            } else {
                HStack(alignment: .top, spacing: 10) { offerCards }
            }
            MembershipOpenButton(isBusy: isOpening, isEnabled: membership.selectedHostedOffer != nil,
                                 isVisible: isPaywallVisible && page == nil, action: beginCheckout)
                .padding(.top, 8)
                .accessibilityIdentifier("hosted-membership-open")
            MembershipPolicyLinks(purchaseDetails: membership.selectedHostedOffer?.trailDesc ?? "")
        }
        .onChange(of: checkoutTrigger) { _, _ in beginCheckout() }
        .fullScreenCover(item: $page, onDismiss: pageClosed) { page in
            HostedPageView(url: page.payDetail, reservationExpiresAt: membership.promotionDeadline)
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
        membership.preparePaywall()
        Task { await membership.refreshEntitlements() }
    }
}
