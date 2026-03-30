import Foundation

public enum CommandParser {
    public static func parse(arguments: [String]) throws -> CLICommand {
        guard let subcommand = arguments.first else {
            throw CameraCaptureError.usage(usageText)
        }

        switch subcommand {
        case "capture":
            return .capture(try parseCapture(arguments: Array(arguments.dropFirst())))
        case "preview":
            return .preview(try parsePreview(arguments: Array(arguments.dropFirst())))
        case "list-devices":
            return .listDevices
        case "request-access":
            return .requestAccess
        case "list-presets":
            return .listPresets
        case "--help", "-h", "help":
            throw CameraCaptureError.usage(usageText)
        default:
            throw CameraCaptureError.usage("unknown command '\(subcommand)'\n\n\(usageText)")
        }
    }

    private static func parsePreview(arguments: [String]) throws -> PreviewRequest {
        var cameraSelector: String?
        var seconds: Double?
        var stayOpen = false

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--camera":
                index += 1
                cameraSelector = try value(after: index, arguments: arguments, flag: "--camera", usage: previewUsageText)
            case "--seconds":
                index += 1
                let value = try value(after: index, arguments: arguments, flag: "--seconds", usage: previewUsageText)
                guard let parsed = Double(value), parsed > 0 else {
                    throw CameraCaptureError.invalidValue(flag: "--seconds", value: value)
                }
                seconds = parsed
            case "--stay-open":
                stayOpen = true
            case "--help", "-h":
                throw CameraCaptureError.usage(previewUsageText)
            default:
                throw CameraCaptureError.usage("unknown option '\(argument)'\n\n\(previewUsageText)")
            }
            index += 1
        }

        if stayOpen, seconds != nil {
            throw CameraCaptureError.unsupported("--seconds and --stay-open are mutually exclusive for preview")
        }

        return PreviewRequest(cameraSelector: cameraSelector, seconds: seconds, stayOpen: stayOpen)
    }

    private static func parseCapture(arguments: [String]) throws -> CaptureRequest {
        var outputPath: String?
        var backend: CaptureBackend = .real
        var cameraSelector: String?
        var preview = false
        var delaySeconds = 0.0
        var preset: SimulatedPreset?

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--output":
                index += 1
                outputPath = try value(after: index, arguments: arguments, flag: "--output")
            case "--backend":
                index += 1
                let value = try value(after: index, arguments: arguments, flag: "--backend")
                guard let parsed = CaptureBackend(rawValue: value) else {
                    throw CameraCaptureError.invalidValue(flag: "--backend", value: value)
                }
                backend = parsed
            case "--camera":
                index += 1
                cameraSelector = try value(after: index, arguments: arguments, flag: "--camera")
            case "--preview":
                preview = true
            case "--delay":
                index += 1
                let value = try value(after: index, arguments: arguments, flag: "--delay")
                guard let parsed = Double(value), parsed >= 0 else {
                    throw CameraCaptureError.invalidValue(flag: "--delay", value: value)
                }
                delaySeconds = parsed
            case "--preset":
                index += 1
                let value = try value(after: index, arguments: arguments, flag: "--preset")
                guard let parsed = SimulatedPreset(rawValue: value) else {
                    throw CameraCaptureError.invalidValue(flag: "--preset", value: value)
                }
                preset = parsed
            case "--help", "-h":
                throw CameraCaptureError.usage(captureUsageText)
            default:
                throw CameraCaptureError.usage("unknown option '\(argument)'\n\n\(captureUsageText)")
            }
            index += 1
        }

        if backend == .simulated, preview {
            throw CameraCaptureError.unsupported("--preview is only supported with --backend real")
        }
        if backend == .simulated, cameraSelector != nil {
            throw CameraCaptureError.unsupported("--camera is only supported with --backend real")
        }
        if backend == .real, preset != nil {
            throw CameraCaptureError.unsupported("--preset is only supported with --backend simulated")
        }

        return CaptureRequest(
            outputPath: outputPath,
            backend: backend,
            cameraSelector: cameraSelector,
            preview: preview,
            delaySeconds: delaySeconds,
            preset: preset
        )
    }

    private static func value(after index: Int, arguments: [String], flag: String, usage: String = captureUsageText) throws -> String {
        guard arguments.indices.contains(index) else {
            throw CameraCaptureError.usage("missing value for \(flag)\n\n\(usage)")
        }
        return arguments[index]
    }

    public static let usageText = """
    Usage:
      camera-capture <command> [options]

    Commands:
      capture         Capture one image to a JPEG file.
      preview         Open a live real-camera preview without writing a file.
      list-devices    List available real camera devices.
      request-access  Request macOS Camera permission through Camera Capture Helper.app.
      list-presets    List simulated capture presets.

    Run `camera-capture <command> --help` for command-specific flags and examples.

    Examples:
      camera-capture capture --backend simulated --preset framing-grid
      camera-capture preview --camera "<camera-name>" --stay-open
      camera-capture request-access
    """

    public static let captureUsageText = """
    Usage:
      camera-capture capture [--output <path>] [--camera <id|name>] [--preview] [--delay <seconds>] [--backend real|simulated] [--preset <name>]

    Description:
      Capture one image and print the absolute output path on success.

    Options:
      --output <path>          Write the JPEG to an explicit path.
      --backend <name>         Choose `real` or `simulated`. Default: real.
      --camera <id|name>       Select a real camera by exact id or name match.
      --preview                Show a preview window before real capture.
      --delay <seconds>        Wait before the real shot so framing/autofocus can settle.
      --preset <name>          Choose a simulated preset when --backend simulated.

    Notes:
      - `--camera`, `--preview`, and `--delay` are real-backend options.
      - `--preset` is a simulated-backend option.
      - Existing output files are never overwritten.

    Examples:
      camera-capture capture --backend simulated --preset low-light
      camera-capture capture --backend real --preview --delay 3
      camera-capture capture --backend real --camera "<camera-name>" --output tmp/capture.jpg
    """

    public static let previewUsageText = """
    Usage:
      camera-capture preview [--camera <id|name>] [--seconds <seconds> | --stay-open]

    Description:
      Open a live real-camera preview window without taking a picture.

    Options:
      --camera <id|name>       Select a real camera by exact id or name match.
      --seconds <seconds>      Auto-close the preview window after the given duration.
      --stay-open              Keep the preview open until you close the window manually.

    Notes:
      - `preview` is a real-camera command only.
      - If neither `--seconds` nor `--stay-open` is passed, preview closes after 10 seconds.
      - Camera permission should be attributed to Camera Capture Helper.app, not the terminal.

    Examples:
      camera-capture preview --stay-open
      camera-capture preview --camera "<camera-name>" --seconds 15
      camera-capture preview --camera "<camera-id>" --stay-open
    """
}
