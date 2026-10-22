import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Development-only, deterministic geometric artwork extending PracticeTheme's
// court/ball palette. Run from the repository root with the approved Xcode Swift.
// No fonts, SF Symbols, third-party artwork, app code or external dependencies.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let inkBlack = CGColor(colorSpace: colorSpace, components: [5.0 / 255, 8.0 / 255, 9.0 / 255, 1])!
let charcoal = CGColor(colorSpace: colorSpace, components: [27.0 / 255, 39.0 / 255, 42.0 / 255, 1])!
let turquoise = CGColor(colorSpace: colorSpace, components: [16.0 / 255, 215.0 / 255, 206.0 / 255, 1])!
let ballSeam = CGColor(colorSpace: colorSpace, components: [4.0 / 255, 19.0 / 255, 19.0 / 255, 1])!
let white = CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!
let gradient = CGGradient(colorsSpace: colorSpace, colors: [charcoal, inkBlack] as CFArray,
                          locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 120, y: 1024),
                           end: CGPoint(x: 900, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Restrained court geometry stays subordinate to the high-contrast central mark.
context.setStrokeColor(white.copy(alpha: 0.13)!)
context.setLineWidth(6)
context.stroke(CGRect(x: 180, y: 180, width: 664, height: 664))
context.move(to: CGPoint(x: 180, y: 512))
context.addLine(to: CGPoint(x: 844, y: 512))
context.strokePath()

// All essential geometry fits inside the Watch's circular mask.
context.saveGState()
context.translateBy(x: 480, y: 520)
context.rotate(by: -.pi / 7)
context.setFillColor(white)
let head = CGRect(x: -154, y: -16, width: 308, height: 372)
context.fillEllipse(in: head)
let throat = CGMutablePath()
throat.move(to: CGPoint(x: -90, y: 38))
throat.addLine(to: CGPoint(x: 90, y: 38))
throat.addLine(to: CGPoint(x: 36, y: -120))
throat.addLine(to: CGPoint(x: -36, y: -120))
throat.closeSubpath()
context.addPath(throat)
context.fillPath()
context.addPath(CGPath(roundedRect: CGRect(x: -36, y: -272, width: 72, height: 190),
                       cornerWidth: 22, cornerHeight: 22, transform: nil))
context.fillPath()
context.setFillColor(charcoal)
let opening = CGMutablePath()
opening.move(to: CGPoint(x: -41, y: 5))
opening.addLine(to: CGPoint(x: 41, y: 5))
opening.addLine(to: CGPoint(x: 0, y: -76))
opening.closeSubpath()
context.addPath(opening)
context.fillPath()
for row in 0..<4 {
    for column in 0..<3 {
        let x = -74 + CGFloat(column) * 74
        let y = 82 + CGFloat(row) * 66
        context.fillEllipse(in: CGRect(x: x - 14, y: y - 14, width: 28, height: 28))
    }
}
context.restoreGState()
context.setFillColor(turquoise)
context.fillEllipse(in: CGRect(x: 650, y: 276, width: 150, height: 150))
context.setStrokeColor(ballSeam.copy(alpha: 0.45)!)
context.setLineWidth(5)
context.addArc(center: CGPoint(x: 699, y: 351), radius: 58,
               startAngle: -.pi / 2.2, endAngle: .pi / 2.2, clockwise: false)
context.strokePath()

let image = context.makeImage()!
for app in ["PadelStrokeLab", "PadelStrokeLab Watch App"] {
    let directory = root.appendingPathComponent("\(app)/Assets.xcassets/AppIcon.appiconset")
    let url = directory.appendingPathComponent("PadelMaster.png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
    print(url.path)
}
