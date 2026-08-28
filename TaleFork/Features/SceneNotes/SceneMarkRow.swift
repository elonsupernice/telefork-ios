import SwiftUI

struct SceneMarkRow: View {
    let mark: SceneMark
    let isPlayable: Bool
    let onResume: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: mark.kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(TaleForkTheme.accentText)
                    .frame(width: 44, height: 44)
                    .background(TaleForkTheme.coral.opacity(0.14), in: .rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mark.kind.localizedTitle)
                        .font(.headline)
                    Text(mark.dramaTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(timeText)
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(TaleForkTheme.accentText)
            }

            LabeledContent {
                Text(mark.episodeTitle)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            } label: {
                Text("\(String(localized: "scene.mark.episode.short")) \(mark.episodeNumber)")
            }
            .font(.subheadline)

            if !mark.note.isEmpty {
                Text(mark.note)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TaleForkTheme.violet.opacity(0.1), in: .rect(cornerRadius: 14))
            }

            HStack(spacing: 12) {
                Button(action: onResume) {
                    Label("scene.mark.resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaleForkTheme.coral)
                .foregroundStyle(TaleForkTheme.ink)
                .disabled(!isPlayable)
                .accessibilityIdentifier("scene-mark-resume")

                Button(role: .destructive, action: onDelete) {
                    Label("scene.mark.delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityHint(Text("scene.mark.delete.hint"))
            }

            if !isPlayable {
                Label("scene.mark.unavailable", systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.background.opacity(0.84), in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }

    private var timeText: String {
        let value = max(Int(mark.positionSeconds.rounded(.down)), 0)
        let minutes = value / 60
        let seconds = value % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}
