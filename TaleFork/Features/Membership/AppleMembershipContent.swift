import StoreKit
import SwiftUI

struct AppleMembershipContent: View {
    @Environment(MembershipStore.self) private var membership
    @Environment(\.purchase) private var purchase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPurchasing = false
    @State private var isRestoring = false
    let isPaywallVisible: Bool
    let onMessage: (LocalizedStringKey) -> Void

    var body: some View {
        MembershipGoldContent(benefitsAccessibilityIdentifier: "apple-membership-checkout", isPaywallVisible: isPaywallVisible) {
            if membership.isLoadingAppleProducts {
                ProgressView("membership.presentation.loading").frame(maxWidth: .infinity, minHeight: 120)
            } else if membership.appleProducts.isEmpty {
                Text("membership.apple.unavailable").font(.subheadline)
                Button("common.retry") { Task { await membership.loadAppleProducts() } }
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) { productCards }
                } else {
                    HStack(alignment: .top, spacing: 10) { productCards }
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 0) {
                if !membership.isLoadingAppleProducts && !membership.appleProducts.isEmpty {
                    if let deadline = membership.promotionDeadline {
                        MembershipCountdownBanner(expiresAt: deadline)
                            .accessibilityIdentifier("membership-promotion-countdown")
                    }
                    MembershipOpenButton(isBusy: isPurchasing, isEnabled: membership.appleProduct != nil && !isRestoring, isVisible: isPaywallVisible, action: beginPurchase)
                        .accessibilityIdentifier("apple-membership-purchase")
                        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : 8)
                    if let product = membership.appleProduct {
                        Text(renewalText(for: product))
                            .font(.caption)
                            .foregroundStyle(MembershipStyle.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("apple-membership-renewal")
                            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : 8)
                    }
                }
                MembershipPolicyLinks(restoreAction: beginRestore, isRestoring: isRestoring,
                                      isRestoreDisabled: isPurchasing || isRestoring)
            }
        }
        .task {
            async let context: Void = TaleForkService.shared.refreshAppleContext()
            await membership.loadAppleProducts()
            await context
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await membership.refreshEntitlements() } }
        }
    }

    private var productCards: some View {
        ForEach(membership.appleProducts) { product in
            MembershipPlanCard(title: periodTitle(product.id), price: product.displayPrice, detail: "", isSelected: membership.appleProduct?.id == product.id) {
                membership.selectAppleProduct(product)
            }
            .frame(maxWidth: membership.appleProducts.count == 1 && !dynamicTypeSize.isAccessibilitySize ? 120 : .infinity)
            .disabled(isPurchasing || isRestoring)
            .accessibilityIdentifier("apple-offer-\(product.id)")
        }
    }

    private func periodTitle(_ id: String) -> String {
        String(localized: String.LocalizationValue(MembershipAccess.periodKey(for: id)))
    }

    private func renewalText(for product: Product) -> String {
        let format = String(localized: "membership.apple.renewal.format")
        return String(format: format, product.displayPrice, periodTitle(product.id))
    }

    private func beginRestore() {
        guard !isRestoring else { return }
        isRestoring = true
        membership.setCheckoutPresented(true)
        Task {
            defer { isRestoring = false; membership.setCheckoutPresented(false) }
            do { try await membership.restorePurchases() }
            catch { onMessage("membership.purchase.failed") }
        }
    }

    private func beginPurchase() {
        guard !isPurchasing, !isRestoring, let product = membership.appleProduct else { return }
        isPurchasing = true
        membership.setCheckoutPresented(true)
        Task {
            defer { isPurchasing = false; membership.setCheckoutPresented(false) }
            do {
                let options: Set<Product.PurchaseOption> = membership.appleAccountToken.map { [.appAccountToken($0)] } ?? []
                switch try await purchase(product, options: options) {
                case .success(let verification):
                    guard case .verified(let transaction) = verification else {
                        onMessage("membership.purchase.unverified")
                        return
                    }
                    await membership.processVerifiedTransaction(transaction, signedTransaction: verification.jwsRepresentation)
                case .pending: onMessage("membership.purchase.pending")
                case .userCancelled: break
                @unknown default: onMessage("membership.purchase.failed")
                }
            } catch { onMessage("membership.purchase.failed") }
        }
    }
}
