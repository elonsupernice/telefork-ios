import UIKit

enum Haptics {
    @MainActor
    static func choice(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    @MainActor
    static func completion(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
