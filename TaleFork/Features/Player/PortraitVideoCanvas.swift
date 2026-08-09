import AVFoundation
import SwiftUI
import UIKit

/// Draws video only. All interaction stays in TaleFork's SwiftUI control layer,
/// preventing AVKit controls from appearing on top of the app controls.
struct PortraitVideoCanvas: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoLayerHostView {
        let view = VideoLayerHostView()
        view.attachedPlayer = player
        return view
    }

    func updateUIView(_ view: VideoLayerHostView, context: Context) {
        view.attachedPlayer = player
    }

    static func dismantleUIView(_ view: VideoLayerHostView, coordinator: Void) {
        view.attachedPlayer = nil
    }
}

final class VideoLayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var attachedPlayer: AVPlayer? {
        get { videoLayer.player }
        set { videoLayer.player = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        videoLayer.backgroundColor = UIColor.black.cgColor
        videoLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
