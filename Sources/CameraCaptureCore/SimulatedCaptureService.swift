import AppKit
import Foundation

public protocol SimulatedCapturing: Sendable {
    func capture(options: CaptureOptions) throws -> URL
}

public struct SimulatedCaptureService: SimulatedCapturing, Sendable {
    public init() {}

    public func capture(options: CaptureOptions) throws -> URL {
        let preset = options.preset ?? .balanced
        switch preset {
        case .timeout:
            throw CameraCaptureError.captureTimeout
        case .writeFailure:
            throw CameraCaptureError.writeFailure("simulated preset triggered a write failure")
        default:
            break
        }

        let width = 1280
        let height = 720
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [],
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw CameraCaptureError.writeFailure("failed to allocate bitmap for simulated capture")
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        drawBackground(preset: preset, width: width, height: height)
        drawOverlay(preset: preset, width: width, height: height)

        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
            throw CameraCaptureError.writeFailure("failed to encode simulated capture as JPEG")
        }
        try data.write(to: options.outputURL)
        return options.outputURL
    }

    private func drawBackground(preset: SimulatedPreset, width: Int, height: Int) {
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        let gradient: NSGradient

        switch preset {
        case .balanced:
            gradient = NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.25, alpha: 1), NSColor(calibratedRed: 0.23, green: 0.47, blue: 0.62, alpha: 1)])!
        case .framingGrid:
            gradient = NSGradient(colors: [NSColor(calibratedRed: 0.13, green: 0.10, blue: 0.18, alpha: 1), NSColor(calibratedRed: 0.38, green: 0.23, blue: 0.18, alpha: 1)])!
        case .softFocus:
            gradient = NSGradient(colors: [NSColor(calibratedRed: 0.51, green: 0.45, blue: 0.40, alpha: 1), NSColor(calibratedRed: 0.82, green: 0.75, blue: 0.64, alpha: 1)])!
        case .lowLight:
            gradient = NSGradient(colors: [NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1), NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.15, alpha: 1)])!
        case .noSignal:
            gradient = NSGradient(colors: [NSColor.black, NSColor(calibratedWhite: 0.15, alpha: 1)])!
        case .timeout, .writeFailure:
            gradient = NSGradient(colors: [NSColor.darkGray, NSColor.gray])!
        }

        gradient.draw(in: rect, angle: 90)
    }

    private func drawOverlay(preset: SimulatedPreset, width: Int, height: Int) {
        let frame = NSRect(x: 120, y: 90, width: width - 240, height: height - 180)
        let framePath = NSBezierPath(roundedRect: frame, xRadius: 24, yRadius: 24)

        NSColor(calibratedWhite: 1, alpha: preset == .lowLight ? 0.18 : 0.30).setFill()
        framePath.fill()

        NSColor(calibratedWhite: 1, alpha: 0.85).setStroke()
        framePath.lineWidth = 4
        framePath.stroke()

        if preset == .framingGrid {
            drawGrid(frame: frame)
        }

        if preset == .softFocus {
            let blurRect = NSRect(x: frame.midX - 140, y: frame.midY - 100, width: 280, height: 200)
            NSColor(calibratedWhite: 1, alpha: 0.15).setFill()
            NSBezierPath(ovalIn: blurRect).fill()
        }

        if preset == .noSignal {
            let bands = stride(from: 0, to: height, by: 30)
            for offset in bands {
                let bandRect = NSRect(x: 0, y: offset, width: width, height: 14)
                NSColor(calibratedWhite: 1, alpha: 0.04).setFill()
                bandRect.fill()
            }
        }

        let title = "SIMULATED CAPTURE"
        let subtitle = "preset: \(preset.rawValue)"
        drawText(title, point: NSPoint(x: 64, y: height - 110), size: 38, alpha: 0.95)
        drawText(subtitle, point: NSPoint(x: 64, y: height - 156), size: 20, alpha: 0.85)
    }

    private func drawGrid(frame: NSRect) {
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 1

        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            let x = frame.minX + frame.width * fraction
            gridPath.move(to: NSPoint(x: x, y: frame.minY))
            gridPath.line(to: NSPoint(x: x, y: frame.maxY))

            let y = frame.minY + frame.height * fraction
            gridPath.move(to: NSPoint(x: frame.minX, y: y))
            gridPath.line(to: NSPoint(x: frame.maxX, y: y))
        }

        NSColor(calibratedWhite: 1, alpha: 0.35).setStroke()
        gridPath.stroke()
    }

    private func drawText(_ value: String, point: NSPoint, size: CGFloat, alpha: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: alpha),
        ]
        value.draw(at: point, withAttributes: attributes)
    }
}
