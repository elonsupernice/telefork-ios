import Observation
import StoreKit

@MainActor
@Observable
final class MembershipStore {
    private(set) var isSubscribed = false
    private(set) var isCheckingEntitlements = true
    private(set) var appleProducts: [Product] = []
    private(set) var selectedAppleProductID = MembershipAccess.weeklyProductID
    private(set) var isLoadingAppleProducts = false
    private(set) var isPresentingCheckout = false
    private var appleProductAttempt = UUID()
    let paywall = MembershipPaywallLoader()
    private(set) var selectedHostedOfferID: String?
    var selectedHostedOffer: HostedMembershipOffer? {
        let offers = paywall.snapshot?.offers ?? []
        return offers.first { $0.id == selectedHostedOfferID }
            ?? offers.first(where: \.isDefault) ?? offers.first
    }
    var appleProduct: Product? {
        appleProducts.first { $0.id == selectedAppleProductID } ?? appleProducts.first
    }
    private(set) var promotionDeadline: Date?
    private(set) var remainingPromotionSeconds = 0

    var membershipScreenshotsAllowed: Bool { TaleForkService.shared.membershipScreenshotsAllowed }
    var appleAccountToken: UUID? { TaleForkService.shared.appleAccountToken }
    var hasExplicitRetentionAttribution: Bool { TaleForkService.shared.hasExplicitRetentionAttribution }
    var isPromotionExpired: Bool { promotionDeadline != nil && remainingPromotionSeconds <= 0 }
    var promotionTimeText: String {
        String(format: "%02d:%02d", remainingPromotionSeconds / 60, remainingPromotionSeconds % 60)
    }

    private var transactionListener: Task<Void, Never>?
    private var finishedTransactionIDs = Set<UInt64>()
    private var deliveredAppleTransactions = Set<String>()
    private var entitlementTask: Task<Void, Never>?
    private var cachedServerMembership: MembershipStatusContent?
    private var membershipAudienceKey = ""
    private var countdownTask: Task<Void, Never>?
    private var retentionDeclineCount = 0

    init() {
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    func canAccess(episodeNumber: Int) -> Bool {
        !MembershipAccess.requiresSubscription(forEpisodeNumber: episodeNumber) || isSubscribed
    }

    func refreshEntitlements() async {
        if let entitlementTask { await entitlementTask.value; return }
        let task = Task { @MainActor in await self.performEntitlementRefresh() }
        entitlementTask = task
        await task.value
        entitlementTask = nil
    }

    private func performEntitlementRefresh() async {
        isCheckingEntitlements = true
        defer { isCheckingEntitlements = false }
        async let serverMembership = try? TaleForkService.shared.refreshMembershipStatus()

        // A partial catalog must not stay cached for the entire app session.
        // Newly configured plans can become available after the first request.
        if !MembershipAccess.hasAllProducts(in: appleProducts.map(\.id)) {
            await loadAppleProducts()
        }
        var hasActiveAppleSubscription = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  MembershipAccess.isMembershipProduct(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                continue
            }
            hasActiveAppleSubscription = true
            break
        }
        let status = await serverMembership
        let audienceKey = TaleForkService.shared.currentAudienceKey
        if !audienceKey.isEmpty, membershipAudienceKey != audienceKey {
                cachedServerMembership = nil
                membershipAudienceKey = audienceKey
        }
        if let status {
            cachedServerMembership = status
        }
        // A transport failure does not revoke an already confirmed entitlement.
        isSubscribed = hasActiveAppleSubscription || cachedServerMembership?.isCurrentlyValid == true
    }

    func preparePaywall() {
        paywall.load {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["TALEFORK_UI_SCREEN"] != nil,
               ProcessInfo.processInfo.environment["TALEFORK_TEST_APPLE_PAYWALL"] == "1" {
                return MembershipPresentationSnapshot(configuration: .init(
                    reviewModel: true, showVip: false, allowedHosts: []), offers: [])
            }
            #endif
            let configuration = try await TaleForkService.shared.refreshMembershipConfiguration()
            let offers = configuration.route == .hostedPage
                ? try await TaleForkService.shared.hostedMembershipOffers() : []
            return MembershipPresentationSnapshot(configuration: configuration, offers: offers)
        }
    }

    func selectHostedOffer(_ offer: HostedMembershipOffer) {
        guard paywall.snapshot?.offers.contains(where: { $0.id == offer.id }) == true else { return }
        selectedHostedOfferID = offer.id
    }

    func setCheckoutPresented(_ presented: Bool) { isPresentingCheckout = presented }

    func loadAppleProducts() async {
        guard !isLoadingAppleProducts else { return }
        let attempt = UUID()
        appleProductAttempt = attempt
        isLoadingAppleProducts = true
        // StoreKit's product request has no caller-specified timeout. Bound
        // the visible spinner independently and reject any late response.
        let deadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard let self, self.appleProductAttempt == attempt else { return }
            self.isLoadingAppleProducts = false
            self.appleProductAttempt = UUID()
        }
        defer {
            deadline.cancel()
            if appleProductAttempt == attempt { isLoadingAppleProducts = false }
        }
        do {
            let products = try await Product.products(for: MembershipAccess.productIDs)
            guard appleProductAttempt == attempt, !Task.isCancelled else { return }
            #if DEBUG
            let catalog = products.map { "\($0.id) [\($0.type.rawValue)] \($0.displayPrice)" }.sorted()
            NSLog("[MembershipStore] StoreKit returned %d products: %@", products.count, catalog.description)
            #endif
            // StoreKit returns an unordered subset. Never fabricate a missing
            // product or its price. Keep the configured week/month/quarter order.
            appleProducts = MembershipAccess.productIDs.compactMap { id in
                products.first { $0.id == id && $0.type == .autoRenewable }
            }
        } catch {
            // Retain previously fetched real products on a transient failure.
            #if DEBUG
            NSLog("[MembershipStore] StoreKit product request failed: %@", String(describing: error))
            #endif
        }
    }

    func selectAppleProduct(_ product: Product) {
        guard appleProducts.contains(where: { $0.id == product.id }) else { return }
        selectedAppleProductID = product.id
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func beginPaywallFlow() {
        guard promotionDeadline == nil else {
            startCountdownTaskIfNeeded()
            return
        }
        let duration = MembershipCountdown.reservationDuration
        promotionDeadline = Date().addingTimeInterval(TimeInterval(duration))
        remainingPromotionSeconds = duration
        retentionDeclineCount = 0
        startCountdownTaskIfNeeded()
    }

    func endPaywallFlow() {
        paywall.cancel()
        countdownTask?.cancel()
        countdownTask = nil
        promotionDeadline = nil
        remainingPromotionSeconds = 0
        retentionDeclineCount = 0
    }

    /// Returns true only when this decline is allowed to leave the paywall.
    func registerRetentionDecline() -> Bool {
        if isSubscribed || isPromotionExpired { return true }
        guard hasExplicitRetentionAttribution else { return true }
        retentionDeclineCount += 1
        return retentionDeclineCount >= 3
    }

    private func startCountdownTaskIfNeeded() {
        guard countdownTask == nil, let deadline = promotionDeadline else { return }
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.remainingPromotionSeconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                if self.remainingPromotionSeconds == 0 { return }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await processVerifiedTransaction(transaction, signedTransaction: result.jwsRepresentation)
    }

    func processVerifiedTransaction(_ transaction: Transaction, signedTransaction: String? = nil) async {
        if let signedTransaction, !deliveredAppleTransactions.contains(signedTransaction) {
            if await TaleForkService.shared.deliverAppleTransaction(signedTransaction) {
                deliveredAppleTransactions.insert(signedTransaction)
            }
        }
        // Business conversions are queued from server-verified facts. Neither
        // a pay-button tap nor the client's current StoreKit price proves one.
        await refreshEntitlements()
        if finishedTransactionIDs.insert(transaction.id).inserted {
            await transaction.finish()
        }
    }

}
