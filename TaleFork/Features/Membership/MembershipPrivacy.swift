import SwiftUI
import UIKit

private extension RedactionReasons {
    /// SwiftUI's iOS 18+ capture-prohibition redaction bit. The app's minimum
    /// deployment target is iOS 18, so it can protect the complete view tree.
    static let screenCaptureProhibited = RedactionReasons(rawValue: 1 << 3)
}

private extension CALayer {
    @discardableResult
    func setHiddenFromScreenCapture(_ hidden: Bool) -> Bool {
        let encodedProperty = "ZGlzYWJsZVVwZGF0ZU1hc2s="
        guard let data = Data(base64Encoded: encodedProperty),
              let property = String(data: data, encoding: .utf8),
              responds(to: NSSelectorFromString(property)) else {
            return false
        }

        let hiddenMask = (1 << 1) | (1 << 4)
        setValue(NSNumber(value: hidden ? hiddenMask : 0), forKey: property)
        return true
    }
}

struct CaptureHiddenContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> CaptureHiddenHostingController<Content> {
        CaptureHiddenHostingController(rootView: content)
    }

    func updateUIViewController(
        _ viewController: CaptureHiddenHostingController<Content>,
        context: Context
    ) {
        viewController.rootView = content
        viewController.applyCaptureProtection()
    }
}

final class CaptureHiddenHostingController<Content: View>: UIViewController {
    private let hostingController: UIHostingController<Content>

    var rootView: Content {
        get { hostingController.rootView }
        set { hostingController.rootView = newValue }
    }

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        applyCaptureProtection()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyCaptureProtection()
    }

    func applyCaptureProtection() {
        loadViewIfNeeded()
        view.layer.setHiddenFromScreenCapture(true)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        hostingController.preferredStatusBarStyle
    }

    override var prefersStatusBarHidden: Bool {
        hostingController.prefersStatusBarHidden
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        hostingController.supportedInterfaceOrientations
    }
}

private struct MembershipCaptureProtectedModifier: ViewModifier {
    let allowed: Bool

    func body(content: Content) -> some View {
        content
        .privacySensitive(false)
        .transformEnvironment(\.redactionReasons) { reasons in
            guard !allowed else { return }
            reasons.insert(.screenCaptureProhibited)
        }
        .background { MembershipProtectionAnchor(allowed: allowed).frame(width: 0, height: 0) }
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
        for window in windows {
            window.layer.setHiddenFromScreenCapture(true)
        }
        let activeWindowIDs = Set(windows.map(ObjectIdentifier.init))
        for id in Array(shields.keys) where !activeWindowIDs.contains(id) {
            shields.removeValue(forKey: id)?.removeFromSuperview()
        }
        for window in windows {
            let id = ObjectIdentifier(window)
#if DEBUG
            let forcedCapture = ProcessInfo.processInfo.environment["TALEFORK_FORCE_SCREEN_CAPTURED"] == "1"
#else
            let forcedCapture = false
#endif
            let needsShield = inactive || window.screen.isCaptured || forcedCapture
            if needsShield {
                let shield: UIView
                if let existing = shields[id] {
                    shield = existing
                } else {
                    shield = UIView(frame: window.bounds)
                    shield.backgroundColor = .black
                    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    shield.isAccessibilityElement = true
                    shield.accessibilityIdentifier = "membership-privacy-shield"
                    shield.accessibilityLabel = "Protected content"
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

