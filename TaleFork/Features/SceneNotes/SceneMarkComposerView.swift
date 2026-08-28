import SwiftUI

struct SceneMarkComposerView: View {
    @Environment(\.dismiss) private var dismiss
    let drama: Drama
    let episode: DramaEpisode
    let positionSeconds: Double
    let onSave: (SceneMarkKind, String) -> Void

    @State private var kind = SceneMarkKind.turningPoint
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("scene.mark.episode") {
                        Text("\(episode.number) · \(timeText)")
                            .monospacedDigit()
                    }
                    LabeledContent("scene.mark.drama") {
                        Text(drama.title.resolved)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("scene.mark.position.header")
                } footer: {
                    Text("scene.mark.position.footer")
                }

                Section("scene.mark.kind.header") {
                    Picker("scene.mark.kind.picker", selection: $kind) {
                        ForEach(SceneMarkKind.allCases) { value in
                            Label(value.localizedTitle, systemImage: value.symbolName)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    TextField("scene.mark.note.placeholder", text: $note, axis: .vertical)
                        .accessibilityIdentifier("scene-mark-note-field")
                        .lineLimit(3...6)
                        .onChange(of: note) { _, value in
                            if value.count > 120 {
                                note = String(value.prefix(120))
                            }
                        }
                } header: {
                    Text("scene.mark.note.header")
                } footer: {
                    Text("scene.mark.note.footer")
                }
            }
            .navigationTitle("scene.mark.composer.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("scene.mark.save") {
                        onSave(kind, note)
                        dismiss()
                    }
                    .accessibilityIdentifier("scene-mark-save")
                    .bold()
                }
            }
        }
    }

    private var timeText: String {
        let value = max(Int(positionSeconds.rounded(.down)), 0)
        let minutes = value / 60
        let seconds = value % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}
