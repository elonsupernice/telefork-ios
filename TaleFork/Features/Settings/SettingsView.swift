import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var store
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var store = store
        GeometryReader { proxy in
            let margin = TaleForkTheme.horizontalMargin(for: proxy.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsHeader

                    SettingsCard(title: "settings.reading", symbol: "text.book.closed") {
                        Picker("settings.appearance", selection: $store.preferences.appearance) {
                            Text("settings.appearance.system").tag(AppPreferences.Appearance.system)
                            Text("settings.appearance.light").tag(AppPreferences.Appearance.light)
                            Text("settings.appearance.dark").tag(AppPreferences.Appearance.dark)
                        }
                        .pickerStyle(.menu)

                        Divider()
                        Toggle("settings.haptics", isOn: $store.preferences.hapticsEnabled)
                            .tint(TaleForkTheme.coral)
                        Divider()
                        Toggle("settings.reduce.motion", isOn: $store.preferences.reduceDecorativeMotion)
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
                .padding(.bottom, 34)
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
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

