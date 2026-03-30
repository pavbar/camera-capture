import AppKit
import Foundation

struct Arguments {
    let outputDir: URL

    static func parse() throws -> Arguments {
        var args = Array(CommandLine.arguments.dropFirst())
        var outputDir: URL?

        while args.isEmpty == false {
            let argument = args.removeFirst()
            switch argument {
            case "--output-dir":
                guard args.isEmpty == false else {
                    throw NSError(domain: "generate_brand_assets", code: 2, userInfo: [NSLocalizedDescriptionKey: "missing value for --output-dir"])
                }
                outputDir = URL(fileURLWithPath: args.removeFirst(), isDirectory: true)
            default:
                throw NSError(domain: "generate_brand_assets", code: 2, userInfo: [NSLocalizedDescriptionKey: "unknown option \(argument)"])
            }
        }

        let resolved = outputDir ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return Arguments(outputDir: resolved)
    }
}

let arguments = try Arguments.parse()
let fileManager = FileManager.default
let outputDir = arguments.outputDir.standardizedFileURL
let iconsetDir = outputDir.appendingPathComponent("CameraCaptureHelper.iconset", isDirectory: true)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sourcePNG = outputDir.appendingPathComponent("camera-capture-helper-source.png")
let sourceLogo = outputDir.appendingPathComponent("camera-capture-logo.png")

struct IconSpec {
    let file: String
    let size: CGFloat
}

let specs: [IconSpec] = [
    .init(file: "icon_16x16.png", size: 16),
    .init(file: "icon_16x16@2x.png", size: 32),
    .init(file: "icon_32x32.png", size: 32),
    .init(file: "icon_32x32@2x.png", size: 64),
    .init(file: "icon_128x128.png", size: 128),
    .init(file: "icon_128x128@2x.png", size: 256),
    .init(file: "icon_256x256.png", size: 256),
    .init(file: "icon_256x256@2x.png", size: 512),
    .init(file: "icon_512x512.png", size: 512),
    .init(file: "icon_512x512@2x.png", size: 1024),
]

func renderImage(size: CGFloat, logo: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.42, blue: 0.58, alpha: 1),
    ])!
    gradient.draw(in: background, angle: 55)

    let glowRect = NSRect(x: size * 0.18, y: size * 0.16, width: size * 0.64, height: size * 0.64)
    let glow = NSBezierPath(ovalIn: glowRect)
    NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.22, alpha: logo ? 0.22 : 0.18).setFill()
    glow.fill()

    let bodyRect = NSRect(x: size * 0.20, y: size * 0.30, width: size * 0.60, height: size * 0.36)
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: size * 0.08, yRadius: size * 0.08)
    NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.0, alpha: 0.95).setFill()
    bodyPath.fill()

    let viewfinderRect = NSRect(x: size * 0.26, y: size * 0.58, width: size * 0.16, height: size * 0.10)
    let viewfinderPath = NSBezierPath(roundedRect: viewfinderRect, xRadius: size * 0.03, yRadius: size * 0.03)
    NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.0, alpha: 0.95).setFill()
    viewfinderPath.fill()

    let lensOuterRect = NSRect(x: size * 0.34, y: size * 0.34, width: size * 0.32, height: size * 0.32)
    let lensOuter = NSBezierPath(ovalIn: lensOuterRect)
    NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.31, alpha: 1).setFill()
    lensOuter.fill()

    let lensRingRect = lensOuterRect.insetBy(dx: size * 0.02, dy: size * 0.02)
    let lensRing = NSBezierPath(ovalIn: lensRingRect)
    NSColor(calibratedRed: 0.11, green: 0.66, blue: 0.79, alpha: 0.95).setStroke()
    lensRing.lineWidth = size * 0.02
    lensRing.stroke()

    let apertureRect = lensOuterRect.insetBy(dx: size * 0.08, dy: size * 0.08)
    NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.28, alpha: 0.95).setFill()
    NSBezierPath(ovalIn: apertureRect).fill()

    let promptText = logo ? "CC" : ">"
    let fontSize = logo ? size * 0.11 : size * 0.14
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.22, alpha: 1),
    ]
    let text = NSAttributedString(string: promptText, attributes: attributes)
    let textSize = text.size()
    let point = NSPoint(
        x: size * 0.50 - textSize.width / 2,
        y: logo ? size * 0.16 : size * 0.19
    )
    text.draw(at: point)

    return image
}

func pngData(for image: NSImage) throws -> Data {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "generate_brand_assets", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to encode PNG"])
    }
    return png
}

for spec in specs {
    let data = try pngData(for: renderImage(size: spec.size, logo: false))
    try data.write(to: iconsetDir.appendingPathComponent(spec.file))
}
try pngData(for: renderImage(size: 1024, logo: false)).write(to: sourcePNG)
try pngData(for: renderImage(size: 1024, logo: true)).write(to: sourceLogo)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", outputDir.appendingPathComponent("CameraCaptureHelper.icns").path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "generate_brand_assets", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}
