import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CatalogStore.self) private var catalog
    @State private var showResetConfirmation = false
    @State private var showAccountDeletionConfirmation = false

    var body: some View {
        @Bindable var store = store
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsHeader

                    SettingsCard(title: "settings.account", symbol: "person.crop.circle") {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                Label("settings.user.id", systemImage: "number")
                                Spacer(minLength: 12)
                                userIDText
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                Label("settings.user.id", systemImage: "number")
                                userIDText
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            showAccountDeletionConfirmation = true
                        } label: {
                            Label("settings.delete.account", systemImage: "person.crop.circle.badge.minus")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }

                    SettingsCard(title: "settings.playback", symbol: "play.rectangle") {
                        Picker("settings.appearance", selection: $store.preferences.appearance) {
                            Text("settings.appearance.system").tag(AppPreferences.Appearance.system)
                            Text("settings.appearance.light").tag(AppPreferences.Appearance.light)
                            Text("settings.appearance.dark").tag(AppPreferences.Appearance.dark)
                        }
                        .pickerStyle(.menu)

                        Divider()
                        Toggle("settings.haptics", isOn: $store.preferences.tactileFeedbackEnabled)
                            .tint(TaleForkTheme.coral)
                        Divider()
                        Toggle("settings.reduce.motion", isOn: $store.preferences.reduceDecorativeMotion)
                            .tint(TaleForkTheme.coral)
                        Divider()
                        Toggle("settings.autoplay", isOn: $store.preferences.autoplayEnabled)
                            .tint(TaleForkTheme.coral)
                    }

                    SettingsCard(title: "settings.about", symbol: "info.circle") {
                        NavigationLink {
                            LocalLegalView(document: .privacy)
                        } label: {
                            settingsRow("settings.privacy", symbol: "hand.raised")
                        }
                        Divider()
                        NavigationLink {
                            LocalLegalView(document: .terms)
                        } label: {
                            settingsRow("settings.terms", symbol: "doc.text")
                        }
                        Divider()
                        HStack {
                            Label("settings.version", systemImage: "number")
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsCard(title: "settings.data", symbol: "internaldrive") {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.shield")
                                .foregroundStyle(TaleForkTheme.mint)
                            Text("settings.offline.privacy")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            Label("settings.reset", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Text("settings.footer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, margin)
                .padding(.top, 18)
                .padding(.bottom, 112)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
        }
        .navigationTitle("tab.settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.reset.title", isPresented: $showResetConfirmation) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.reset.confirm", role: .destructive) {
                store.resetAllProgress()
            }
        } message: {
            Text("settings.reset.message")
        }
        .alert("settings.delete.account.title", isPresented: $showAccountDeletionConfirmation) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.delete.account.confirm", role: .destructive) {
                TactileFeedback.success(enabled: store.preferences.tactileFeedbackEnabled)
                catalog.deleteLocalAccount()
                store.deleteLocalAccount()
            }
        } message: {
            Text("settings.delete.account.message")
        }
        .task { await catalog.load() }
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            BrandMark(size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("TaleFork")
                    .font(.system(.title2, design: .rounded, weight: .black))
                Text("settings.tagline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [TaleForkTheme.violet.opacity(0.18), TaleForkTheme.coral.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .dynamicTypeSize(.xSmall ... .xxxLarge)
    }

    private func settingsRow(_ title: LocalizedStringKey, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var userIDLabel: String {
        if !catalog.currentUserID.isEmpty { return catalog.currentUserID }
        return catalog.isLoading ? String(localized: "settings.user.loading") : String(localized: "settings.user.unavailable")
    }

    private var userIDText: some View {
        Text(userIDLabel)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .textSelection(.enabled)
            .accessibilityLabel(Text("settings.user.id"))
            .accessibilityValue(Text(userIDLabel))
    }
}

private struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: Content

    init(title: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(TaleForkTheme.violet)
                .textCase(.uppercase)
                .dynamicTypeSize(.xSmall ... .xxxLarge)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
