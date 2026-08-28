import StoreKit
import SwiftUI

struct MembershipPaywallView: View {
    @Environment(MembershipStore.self) private var membership
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseMessage: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                marketingContent
                Divider().opacity(0.45)
                SubscriptionStoreView(productIDs: [MembershipAccess.weeklyProductID])
                    .subscriptionStoreControlStyle(.buttons)
                    .subscriptionStoreButtonLabel(.multiline)
                    .storeButton(.visible, for: .restorePurchases)
                    .storeButton(.hidden, for: .cancellation)
                    .storeButton(.visible, for: .policies)
                    .subscriptionStorePolicyDestination(for: .privacyPolicy) {
                        LocalLegalView(document: .privacy)
                    }
                    .subscriptionStorePolicyDestination(for: .termsOfService) {
                        LocalLegalView(document: .terms)
                    }
                    .onInAppPurchaseCompletion { _, result in
                        switch result {
                        case .success(.success(.verified(let transaction))):
                            await membership.refreshEntitlements()
                            await transaction.finish()
                        case .success(.pending):
                            purchaseMessage = "membership.purchase.pending"
                        case .success(.userCancelled):
                            break
                        case .success(.success(.unverified)):
                            purchaseMessage = "membership.purchase.unverified"
                        case .failure:
                            purchaseMessage = "membership.purchase.failed"
                        @unknown default:
                            purchaseMessage = "membership.purchase.failed"
                        }
                    }
            }
            .background(PaperBackground())
            .navigationTitle("membership.navigation.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
        .task { await membership.refreshEntitlements() }
        .onChange(of: membership.isSubscribed) { _, isSubscribed in
            if isSubscribed { dismiss() }
        }
        .alert("membership.purchase.status", isPresented: purchaseMessageBinding) {
            Button("common.done") { purchaseMessage = nil }
        } message: {
            if let purchaseMessage { Text(purchaseMessage) }
        }
    }

    private var marketingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(TaleForkTheme.coral)
                .frame(width: 70, height: 70)
                .background(TaleForkTheme.violet.opacity(0.14), in: Circle())

            VStack(spacing: 6) {
                Text("membership.title")
                    .font(.system(.title, design: .rounded, weight: .black))
                Text("membership.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                benefit("play.rectangle.on.rectangle.fill", "membership.benefit.episodes")
                benefit("arrow.trianglehead.2.clockwise.rotate.90", "membership.benefit.renewal")
                benefit("checkmark.seal.fill", "membership.benefit.price")
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
            .foregroundStyle(.primary)
    }
}
