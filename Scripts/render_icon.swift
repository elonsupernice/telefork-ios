import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "TaleFork/Resources/Assets.xcassets/AppIcon.appiconset/TaleFork-AppIcon-1024.png"
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to create icon canvas")
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red / 255, green / 255, blue / 255, alpha])!
}

context.setFillColor(color(23, 21, 43))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

context.setStrokeColor(color(120, 104, 230, 0.38))
context.setLineWidth(32)
context.strokeEllipse(in: CGRect(x: 160, y: 160, width: 704, height: 704))

context.setStrokeColor(color(255, 107, 94))
context.setLineWidth(92)
context.setLineCap(.round)
context.setLineJoin(.round)
context.beginPath()
context.move(to: CGPoint(x: 512, y: 234))
context.addLine(to: CGPoint(x: 512, y: 514))
context.addLine(to: CGPoint(x: 320, y: 706))
context.move(to: CGPoint(x: 512, y: 514))
context.addLine(to: CGPoint(x: 704, y: 706))
context.strokePath()

context.setFillColor(color(85, 214, 190))
context.fillEllipse(in: CGRect(x: 448, y: 170, width: 128, height: 128))
context.setFillColor(color(247, 243, 234))
context.fillEllipse(in: CGRect(x: 276, y: 662, width: 88, height: 88))
context.fillEllipse(in: CGRect(x: 660, y: 662, width: 88, height: 88))

guard let cgImage = context.makeImage() else { fatalError("Unable to render icon") }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
