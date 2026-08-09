import AppKit
import AVFoundation
import CoreVideo

struct ClipSpec {
    let image: String
    let output: String
    let duration: Double
    let zoomStart: CGFloat
    let zoomEnd: CGFloat
    let panX: CGFloat
    let panY: CGFloat
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let images = root.appendingPathComponent("TaleFork/Resources/DramaImages")
let videos = root.appendingPathComponent("TaleFork/Resources/Videos")
try FileManager.default.createDirectory(at: videos, withIntermediateDirectories: true)

let clips = [
    ClipSpec(image: "rain-stop-arrival.png", output: "rain-01-arrival.mp4", duration: 6.0, zoomStart: 1.00, zoomEnd: 1.08, panX: -0.02, panY: 0.01),
    ClipSpec(image: "rain-stop-phone.png", output: "rain-02-letter.mp4", duration: 6.0, zoomStart: 1.07, zoomEnd: 1.00, panX: 0.02, panY: -0.01),
    ClipSpec(image: "rain-stop-meeting.png", output: "rain-03-meeting.mp4", duration: 6.0, zoomStart: 1.00, zoomEnd: 1.10, panX: 0.00, panY: 0.02),
    ClipSpec(image: "rain-stop-phone.png", output: "rain-04-answer.mp4", duration: 6.0, zoomStart: 1.02, zoomEnd: 1.12, panX: 0.06, panY: 0.02),
    ClipSpec(image: "rain-stop-dawn.png", output: "rain-05-dawn.mp4", duration: 6.0, zoomStart: 1.06, zoomEnd: 1.00, panX: 0.00, panY: -0.02),
    ClipSpec(image: "rain-stop-call.png", output: "rain-06-call.mp4", duration: 6.0, zoomStart: 1.00, zoomEnd: 1.08, panX: -0.03, panY: 0.00),
]

let width = 720
let height = 1280
let fps: Int32 = 24

func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:],
    ]
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
    return buffer!
}

func render(_ image: CGImage, spec: ClipSpec, progress: CGFloat) -> CVPixelBuffer {
    let buffer = pixelBuffer(width: width, height: height)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )!

    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let imageSize = CGSize(width: image.width, height: image.height)
    let baseScale = max(CGFloat(width) / imageSize.width, CGFloat(height) / imageSize.height)
    let eased = progress * progress * (3 - 2 * progress)
    let zoom = spec.zoomStart + (spec.zoomEnd - spec.zoomStart) * eased
    let drawSize = CGSize(width: imageSize.width * baseScale * zoom, height: imageSize.height * baseScale * zoom)
    let x = (CGFloat(width) - drawSize.width) / 2 + spec.panX * CGFloat(width) * eased
    let y = (CGFloat(height) - drawSize.height) / 2 + spec.panY * CGFloat(height) * eased

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(origin: CGPoint(x: x, y: y), size: drawSize))

    let top = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.black.withAlphaComponent(0.24).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        top,
        start: CGPoint(x: 0, y: CGFloat(height)),
        end: CGPoint(x: 0, y: CGFloat(height) * 0.72),
        options: []
    )
    return buffer
}

func write(_ spec: ClipSpec) async throws {
    let source = images.appendingPathComponent(spec.image)
    let destination = videos.appendingPathComponent(spec.output)
    try? FileManager.default.removeItem(at: destination)
    guard let image = NSImage(contentsOf: source)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "TaleForkVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load \(source.path)"])
    }

    let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 2_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
    guard writer.canAdd(input) else { throw NSError(domain: "TaleForkVideo", code: 2) }
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let frames = Int(spec.duration * Double(fps))
    for index in 0..<frames {
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
        let progress = frames > 1 ? CGFloat(index) / CGFloat(frames - 1) : 0
        let time = CMTime(value: Int64(index), timescale: fps)
        guard adaptor.append(render(image, spec: spec, progress: progress), withPresentationTime: time) else {
            throw writer.error ?? NSError(domain: "TaleForkVideo", code: 3)
        }
    }
    input.markAsFinished()
    await writer.finishWriting()
    if writer.status != .completed { throw writer.error ?? NSError(domain: "TaleForkVideo", code: 4) }
    print("Created \(destination.lastPathComponent)")
}

for clip in clips {
    try await write(clip)
}
