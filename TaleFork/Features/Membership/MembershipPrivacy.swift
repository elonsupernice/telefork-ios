import SwiftUI
import UIKit

private struct MembershipCaptureProtectedModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let allowed: Bool
    @State private var isCaptured = UIScreen.main.isCaptured
    @State private var showScreenshotNotice = false

    func body(content: Content) -> some View {
        ZStack {
            content
            if !allowed && showScreenshotNotice && scenePhase == .active && !isCaptured {
                Text("membership.capture.screenshot.notice")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .zIndex(101)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background { MembershipProtectionAnchor(allowed: allowed).frame(width: 0, height: 0) }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isCaptured = UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            guard !allowed else { return }
            showScreenshotNotice = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { showScreenshotNotice = false }
            }
        }
    }
}

/// One synchronous window-level shield covers the paywall, retention and nested
/// membership views. UIKit's will-resign callbacks run before App-switcher snapshots.
@MainActor
final class MembershipScreenProtection: NSObject {
    static let shared = MembershipScreenProtection()
    private var protectedViews: [ObjectIdentifier: WeakProtectionAnchor] = [:]
    private var shields: [ObjectIdentifier: UIView] = [:]
    private var observersActive = false
    private var inactive = UIApplication.shared.applicationState != .active

    func attach(_ anchor: MembershipProtectionAnchorView) {
        protectedViews[ObjectIdentifier(anchor)] = WeakProtectionAnchor(anchor)
        if !observersActive {
            inactive = UIApplication.shared.applicationState != .active
            observersActive = true
            NotificationCenter.default.addObserver(self, selector: #selector(willDeactivate), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(didActivate), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(willDeactivate), name: UIScene.willDeactivateNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(didActivate), name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(captureChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
        }
        updateShields()
    }

    func detach(_ anchor: MembershipProtectionAnchorView) {
        protectedViews.removeValue(forKey: ObjectIdentifier(anchor))
        updateShields()
        if protectedViews.isEmpty {
            NotificationCenter.default.removeObserver(self)
            observersActive = false
        }
    }

    @objc private func willDeactivate() { inactive = true; updateShields() }
    @objc private func didActivate() { inactive = false; updateShields() }
    @objc private func captureChanged() { updateShields() }

    private func updateShields() {
        protectedViews = protectedViews.filter { $0.value.anchor != nil }
        let windows = protectedViews.values.compactMap { reference -> UIWindow? in
            guard let anchor = reference.anchor, !anchor.allowed else { return nil }
            return anchor.window
        }
        let activeWindowIDs = Set(windows.map(ObjectIdentifier.init))
        for id in Array(shields.keys) where !activeWindowIDs.contains(id) {
            shields.removeValue(forKey: id)?.removeFromSuperview()
        }
        for window in windows {
            let id = ObjectIdentifier(window)
            let needsShield = inactive || window.screen.isCaptured
            if needsShield {
                let shield: UIView
                if let existing = shields[id] {
                    shield = existing
                } else {
                    shield = UIView(frame: window.bounds)
                    shield.backgroundColor = .systemBackground
                    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    shield.accessibilityIdentifier = "membership-privacy-shield"
                    let label = UILabel()
                    label.text = String(localized: "membership.capture.hidden")
                    label.textColor = .secondaryLabel
                    label.font = .preferredFont(forTextStyle: .headline)
                    label.adjustsFontForContentSizeCategory = true
                    label.numberOfLines = 0
                    label.textAlignment = .center
                    label.translatesAutoresizingMaskIntoConstraints = false
                    shield.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
                        label.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
                        label.leadingAnchor.constraint(greaterThanOrEqualTo: shield.leadingAnchor, constant: 24),
                        label.trailingAnchor.constraint(lessThanOrEqualTo: shield.trailingAnchor, constant: -24)
                    ])
                    shields[id] = shield
                    window.addSubview(shield)
                }
                window.bringSubviewToFront(shield)
            } else {
                shields.removeValue(forKey: id)?.removeFromSuperview()
            }
        }
    }
}

private final class WeakProtectionAnchor {
    weak var anchor: MembershipProtectionAnchorView?
    init(_ anchor: MembershipProtectionAnchorView) { self.anchor = anchor }
}

final class MembershipProtectionAnchorView: UIView {
    var allowed = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { MembershipScreenProtection.shared.detach(self) }
        else { MembershipScreenProtection.shared.attach(self) }
    }
}

private struct MembershipProtectionAnchor: UIViewRepresentable {
    let allowed: Bool
    func makeUIView(context: Context) -> MembershipProtectionAnchorView {
        let view = MembershipProtectionAnchorView()
        view.allowed = allowed
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: MembershipProtectionAnchorView, context: Context) {
        view.allowed = allowed
        if view.window != nil { MembershipScreenProtection.shared.attach(view) }
    }
    static func dismantleUIView(_ view: MembershipProtectionAnchorView, coordinator: ()) {
        MembershipScreenProtection.shared.detach(view)
    }
}

extension View {
    func membershipCaptureProtected(allowed: Bool) -> some View {
        modifier(MembershipCaptureProtectedModifier(allowed: allowed))
    }
}

