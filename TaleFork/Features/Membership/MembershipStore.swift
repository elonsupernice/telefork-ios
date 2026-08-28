import Observation
import StoreKit

@MainActor
@Observable
final class MembershipStore {
    private(set) var isSubscribed = false
    private(set) var isCheckingEntitlements = true

    private var transactionListener: Task<Void, Never>?

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
        isCheckingEntitlements = true
        defer { isCheckingEntitlements = false }

        var hasActiveWeeklySubscription = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == MembershipAccess.weeklyProductID,
                  transaction.revocationDate == nil else {
                continue
            }
            hasActiveWeeklySubscription = true
            break
        }
        isSubscribed = hasActiveWeeklySubscription
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await refreshEntitlements()
        await transaction.finish()
    }
}
