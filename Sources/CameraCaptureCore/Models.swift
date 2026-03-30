import Foundation

public enum CaptureBackend: String, Codable, CaseIterable, Sendable {
    case real
    case simulated
}

public enum SimulatedPreset: String, Codable, CaseIterable, Sendable {
    case balanced
    case framingGrid = "framing-grid"
    case softFocus = "soft-focus"
    case lowLight = "low-light"
    case noSignal = "no-signal"
    case timeout
    case writeFailure = "write-failure"
}

public enum PermissionState: String, Codable, Sendable {
    case granted
    case denied
    case restricted
    case notDetermined = "not-determined"
}

public struct CameraDevice: Sendable, Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct CaptureOptions: Sendable, Equatable {
    public let outputURL: URL
    public let backend: CaptureBackend
    public let cameraSelector: String?
    public let preview: Bool
    public let delaySeconds: Double
    public let preset: SimulatedPreset?

    public init(
        outputURL: URL,
        backend: CaptureBackend,
        cameraSelector: String?,
        preview: Bool,
        delaySeconds: Double,
        preset: SimulatedPreset?
    ) {
        self.outputURL = outputURL
        self.backend = backend
        self.cameraSelector = cameraSelector
        self.preview = preview
        self.delaySeconds = delaySeconds
        self.preset = preset
    }
}

public enum CLICommand: Sendable, Equatable {
    case capture(CaptureRequest)
    case preview(PreviewRequest)
    case listDevices
    case requestAccess
    case listPresets
}

public enum HelperAction: String, Codable, Sendable, Equatable {
    case capture
    case preview
    case requestAccess = "request-access"
}

public struct HelperRequestEnvelope: Codable, Sendable, Equatable {
    public let action: HelperAction
    public let responseFile: String
    public let cancelFile: String?
    public let capture: CaptureRequest?
    public let preview: PreviewRequest?

    public init(
        action: HelperAction,
        responseFile: String,
        cancelFile: String? = nil,
        capture: CaptureRequest? = nil,
        preview: PreviewRequest? = nil
    ) {
        self.action = action
        self.responseFile = responseFile
        self.cancelFile = cancelFile
        self.capture = capture
        self.preview = preview
    }
}

public struct HelperResponseEnvelope: Codable, Sendable, Equatable {
    public let success: Bool
    public let permissionState: PermissionState?
    public let outputPath: String?
    public let message: String?

    public init(
        success: Bool,
        permissionState: PermissionState? = nil,
        outputPath: String? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.permissionState = permissionState
        self.outputPath = outputPath
        self.message = message
    }
}

public enum BuildInfo {
    public static let sharedVersion = "2026.03.27-app-bundle-v1"
}

public struct CaptureRequest: Codable, Sendable, Equatable {
    public let outputPath: String?
    public let backend: CaptureBackend
    public let cameraSelector: String?
    public let preview: Bool
    public let delaySeconds: Double
    public let preset: SimulatedPreset?

    public init(
        outputPath: String?,
        backend: CaptureBackend,
        cameraSelector: String?,
        preview: Bool,
        delaySeconds: Double,
        preset: SimulatedPreset?
    ) {
        self.outputPath = outputPath
        self.backend = backend
        self.cameraSelector = cameraSelector
        self.preview = preview
        self.delaySeconds = delaySeconds
        self.preset = preset
    }
}

public struct PreviewRequest: Codable, Sendable, Equatable {
    public let cameraSelector: String?
    public let seconds: Double?
    public let stayOpen: Bool

    public init(
        cameraSelector: String?,
        seconds: Double?,
        stayOpen: Bool
    ) {
        self.cameraSelector = cameraSelector
        self.seconds = seconds
        self.stayOpen = stayOpen
    }
}

public enum CameraCaptureError: Error, LocalizedError, Equatable {
    case usage(String)
    case unsupported(String)
    case invalidValue(flag: String, value: String)
    case fileExists(URL)
    case helperNotFound(String)
    case helperFailed(String)
    case permissionDenied
    case cameraNotFound(String)
    case captureTimeout
    case writeFailure(String)

    public var errorDescription: String? {
        switch self {
        case .usage(let message):
            return message
        case .unsupported(let message):
            return message
        case .invalidValue(let flag, let value):
            return "invalid value '\(value)' for \(flag)"
        case .fileExists(let url):
            return "refusing to overwrite existing file at \(url.path)"
        case .helperNotFound(let message):
            return message
        case .helperFailed(let message):
            return message
        case .permissionDenied:
            return "camera permission denied"
        case .cameraNotFound(let selector):
            return "camera not found for selector '\(selector)'"
        case .captureTimeout:
            return "capture timed out"
        case .writeFailure(let message):
            return message
        }
    }
}
