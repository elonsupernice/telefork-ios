import SwiftUI

struct AccountSettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(CatalogStore.self) private var catalog
    @State private var showsDeletionConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            Section("settings.account") {
                Button(role: .destructive, action: confirmDeletion) {
                    HStack(spacing: 12) {
                        Label("settings.delete.account", systemImage: "person.crop.circle.badge.minus")
                        Spacer(minLength: 8)
                        if isDeleting { ProgressView() }
                    }
                    .frame(minHeight: 44)
                }
                .disabled(isDeleting)
                .accessibilityIdentifier("settings-delete-account")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.general")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("account-settings-page")
        .alert("settings.delete.account.title", isPresented: $showsDeletionConfirmation) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.delete.account.confirm", role: .destructive, action: deleteAccount)
        } message: {
            Text("settings.delete.account.message")
        }
    }

    private func confirmDeletion() {
        showsDeletionConfirmation = true
    }

    private func deleteAccount() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            defer { isDeleting = false }
            guard await catalog.deleteAccount() else { return }
            TactileFeedback.success(enabled: progress.preferences.tactileFeedbackEnabled)
            progress.deleteLocalAccount()
        }
    }
}
