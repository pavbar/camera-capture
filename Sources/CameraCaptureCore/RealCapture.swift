import Foundation
import Darwin
import Dispatch

#if canImport(AVFoundation)
import AVFoundation
#endif

public protocol DeviceListing: Sendable {
    func listDevices() throws -> [CameraDevice]
}

public protocol RealCaptureInvoking: Sendable {
    func capture(options: CaptureOptions) throws -> URL
}

public protocol RealPreviewInvoking: Sendable {
    func preview(request: PreviewRequest) throws
}

public protocol RealAccessInvoking: Sendable {
    func requestAccess() throws -> PermissionState
}

public struct RealCameraDeviceService: DeviceListing, Sendable {
    public init() {}

    public func listDevices() throws -> [CameraDevice] {
        #if canImport(AVFoundation)
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
        #else
        return []
        #endif
    }
}

public protocol CommandRunning: Sendable {
    func run(executable: URL, arguments: [String]) throws -> CommandResult
}

public struct CommandResult: Sendable, Equatable {
    public let terminationStatus: Int32
    public let stdout: String
    public let stderr: String

    public init(terminationStatus: Int32, stdout: String, stderr: String) {
        self.terminationStatus = terminationStatus
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct ProcessRunner: CommandRunning, Sendable {
    public init() {}

    public func run(executable: URL, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return CommandResult(
            terminationStatus: process.terminationStatus,
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public enum HelperLaunchTarget: Sendable, Equatable {
    case appBundle(URL)
    case executable(URL)
}

public protocol HelperTransporting: Sendable {
    func send(request: HelperRequestEnvelope) throws -> HelperResponseEnvelope
}

public struct DirectExecutableHelperTransport: HelperTransporting, Sendable {
    public let executableURL: URL
    public let runner: any CommandRunning

    public init(
        executableURL: URL,
        runner: any CommandRunning = ProcessRunner()
    ) {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func send(request: HelperRequestEnvelope) throws -> HelperResponseEnvelope {
        let requestURL = try writeRequest(request)
        let result = try runner.run(executable: executableURL, arguments: ["--request-file", requestURL.path])
        guard result.terminationStatus == 0 else {
            throw CameraCaptureError.helperFailed(result.stderr.isEmpty ? "helper exited with status \(result.terminationStatus)" : result.stderr)
        }
        return try readResponse(at: URL(fileURLWithPath: request.responseFile))
    }

    private func writeRequest(_ request: HelperRequestEnvelope) throws -> URL {
        let responseURL = URL(fileURLWithPath: request.responseFile)
        let requestURL = responseURL.deletingLastPathComponent().appendingPathComponent("request.json")
        try FileManager.default.createDirectory(at: requestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(request)
        try data.write(to: requestURL)
        return requestURL
    }
}

public struct AppBundleHelperTransport: HelperTransporting, Sendable {
    public let appURL: URL
    public let runner: any CommandRunning

    public init(
        appURL: URL,
        runner: any CommandRunning = ProcessRunner()
    ) {
        self.appURL = appURL
        self.runner = runner
    }

    public func send(request: HelperRequestEnvelope) throws -> HelperResponseEnvelope {
        let requestURL = try writeRequest(request)
        if runner is ProcessRunner {
            return try launchAndWaitForResponse(request: request, requestURL: requestURL)
        }

        let result = try runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/open"),
            arguments: ["-n", "-W", "-a", appURL.path, "--args", "--request-file", requestURL.path]
        )
        guard result.terminationStatus == 0 else {
            throw CameraCaptureError.helperFailed(result.stderr.isEmpty ? "failed to launch helper app bundle" : result.stderr)
        }
        return try readResponse(at: URL(fileURLWithPath: request.responseFile))
    }

    private func writeRequest(_ request: HelperRequestEnvelope) throws -> URL {
        let responseURL = URL(fileURLWithPath: request.responseFile)
        let requestURL = responseURL.deletingLastPathComponent().appendingPathComponent("request.json")
        try FileManager.default.createDirectory(at: requestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(request)
        try data.write(to: requestURL)
        return requestURL
    }

    private func launchAndWaitForResponse(request: HelperRequestEnvelope, requestURL: URL) throws -> HelperResponseEnvelope {
        InterruptMonitor.installIfNeeded()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-W", "-a", appURL.path, "--args", "--request-file", requestURL.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()

        let responseURL = URL(fileURLWithPath: request.responseFile)
        let cancelURL = request.cancelFile.map(URL.init(fileURLWithPath:))
        var cancellationSent = false

        while process.isRunning {
            if FileManager.default.fileExists(atPath: responseURL.path) {
                process.waitUntilExit()
                return try readResponse(at: responseURL)
            }

            if InterruptMonitor.wasInterrupted, let cancelURL, cancellationSent == false {
                FileManager.default.createFile(atPath: cancelURL.path, contents: Data())
                cancellationSent = true
            }

            Thread.sleep(forTimeInterval: 0.1)
        }

        if InterruptMonitor.wasInterrupted, let cancelURL, cancellationSent == false {
            FileManager.default.createFile(atPath: cancelURL.path, contents: Data())
        }

        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 || FileManager.default.fileExists(atPath: responseURL.path) else {
            throw CameraCaptureError.helperFailed(stderr.isEmpty ? "failed to launch helper app bundle" : stderr)
        }
        return try readResponse(at: responseURL)
    }
}

private enum InterruptMonitor {
    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var interrupted: sig_atomic_t = 0

    static var wasInterrupted: Bool {
        interrupted != 0
    }

    static func installIfNeeded() {
        guard installed == false else { return }
        signal(SIGINT, cameraCaptureInterruptHandler)
        installed = true
    }

    static func markInterrupted() {
        interrupted = 1
    }
}

private func cameraCaptureInterruptHandler(_: Int32) -> Void {
    InterruptMonitor.markInterrupted()
}

private func readResponse(at url: URL) throws -> HelperResponseEnvelope {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CameraCaptureError.helperFailed("helper did not produce a response file at \(url.path)")
    }
    let data = try Data(contentsOf: url)
    let response = try JSONDecoder().decode(HelperResponseEnvelope.self, from: data)
    if response.success == false {
        if response.permissionState == .denied {
            throw CameraCaptureError.permissionDenied
        }
        throw CameraCaptureError.helperFailed(response.message ?? "helper reported a failure")
    }
    return response
}

public struct HelperRealCaptureInvoker: RealCaptureInvoking, Sendable {
    public let transport: any HelperTransporting
    public let temporaryDirectory: URL

    public init(
        transport: any HelperTransporting,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.transport = transport
        self.temporaryDirectory = temporaryDirectory
    }

    public func capture(options: CaptureOptions) throws -> URL {
        let envelope = try requestEnvelope(
            action: .capture,
            capture: CaptureRequest(
                outputPath: options.outputURL.path,
                backend: .real,
                cameraSelector: options.cameraSelector,
                preview: options.preview,
                delaySeconds: options.delaySeconds,
                preset: nil
            ),
            preview: nil
        )
        let response = try transport.send(request: envelope)
        return URL(fileURLWithPath: response.outputPath ?? options.outputURL.path)
    }

    private func requestEnvelope(
        action: HelperAction,
        capture: CaptureRequest?,
        preview: PreviewRequest?
    ) throws -> HelperRequestEnvelope {
        let workspace = temporaryDirectory.appendingPathComponent("camera-capture-helper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let responseFile = workspace.appendingPathComponent("response.json").path
        let cancelFile = workspace.appendingPathComponent("cancel.signal").path
        return HelperRequestEnvelope(action: action, responseFile: responseFile, cancelFile: cancelFile, capture: capture, preview: preview)
    }
}

public struct HelperRealPreviewInvoker: RealPreviewInvoking, Sendable {
    public let transport: any HelperTransporting
    public let temporaryDirectory: URL

    public init(
        transport: any HelperTransporting,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.transport = transport
        self.temporaryDirectory = temporaryDirectory
    }

    public func preview(request: PreviewRequest) throws {
        let envelope = try requestEnvelope(action: .preview, preview: request)
        _ = try transport.send(request: envelope)
    }

    private func requestEnvelope(action: HelperAction, preview: PreviewRequest) throws -> HelperRequestEnvelope {
        let workspace = temporaryDirectory.appendingPathComponent("camera-capture-helper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let responseFile = workspace.appendingPathComponent("response.json").path
        let cancelFile = workspace.appendingPathComponent("cancel.signal").path
        return HelperRequestEnvelope(action: action, responseFile: responseFile, cancelFile: cancelFile, preview: preview)
    }
}

public struct HelperRealAccessInvoker: RealAccessInvoking, Sendable {
    public let transport: any HelperTransporting
    public let temporaryDirectory: URL

    public init(
        transport: any HelperTransporting,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.transport = transport
        self.temporaryDirectory = temporaryDirectory
    }

    public func requestAccess() throws -> PermissionState {
        let workspace = temporaryDirectory.appendingPathComponent("camera-capture-helper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let responseFile = workspace.appendingPathComponent("response.json").path
        let cancelFile = workspace.appendingPathComponent("cancel.signal").path
        let response = try transport.send(request: HelperRequestEnvelope(action: .requestAccess, responseFile: responseFile, cancelFile: cancelFile))
        return response.permissionState ?? .restricted
    }
}

public enum HelperLocator {
    public static let helperAppName = "Camera Capture Helper.app"
    public static let helperExecutableName = "camera-capture-helper"

    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentExecutable: URL,
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) throws -> HelperLaunchTarget {
        let resolvedHomeDirectory = homeDirectory
            ?? environment["HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? fileManager.homeDirectoryForCurrentUser

        if let override = environment["CAMERA_CAPTURE_HELPER_PATH"], override.isEmpty == false {
            let url = URL(fileURLWithPath: override)
            guard fileManager.isExecutableFile(atPath: url.path) else {
                throw CameraCaptureError.helperNotFound("configured CAMERA_CAPTURE_HELPER_PATH is not executable: \(url.path)")
            }
            return .executable(url)
        }

        if let appOverride = environment["CAMERA_CAPTURE_HELPER_APP"], appOverride.isEmpty == false {
            let url = URL(fileURLWithPath: appOverride)
            guard fileManager.fileExists(atPath: url.path) else {
                throw CameraCaptureError.helperNotFound("configured CAMERA_CAPTURE_HELPER_APP does not exist: \(url.path)")
            }
            return .appBundle(url)
        }

        let installedApp = resolvedHomeDirectory
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent(helperAppName, isDirectory: true)
        if fileManager.fileExists(atPath: installedApp.path) {
            return .appBundle(installedApp)
        }

        let siblingBundle = currentExecutable
            .deletingLastPathComponent()
            .appendingPathComponent(helperAppName, isDirectory: true)
        if fileManager.fileExists(atPath: siblingBundle.path) {
            return .appBundle(siblingBundle)
        }

        let rawSibling = currentExecutable.deletingLastPathComponent().appendingPathComponent(helperExecutableName)
        if fileManager.isExecutableFile(atPath: rawSibling.path) {
            return .executable(rawSibling)
        }

        throw CameraCaptureError.helperNotFound(
            "Camera Capture Helper.app not found in ~/Applications or next to \(currentExecutable.lastPathComponent); set CAMERA_CAPTURE_HELPER_APP or CAMERA_CAPTURE_HELPER_PATH to override"
        )
    }

    public static func makeTransport(
        target: HelperLaunchTarget,
        runner: any CommandRunning = ProcessRunner()
    ) -> any HelperTransporting {
        switch target {
        case .appBundle(let url):
            return AppBundleHelperTransport(appURL: url, runner: runner)
        case .executable(let url):
            return DirectExecutableHelperTransport(executableURL: url, runner: runner)
        }
    }
}
