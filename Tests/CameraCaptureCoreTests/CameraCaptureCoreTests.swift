import CameraCaptureCore
import Foundation
import Testing

struct CameraCaptureCoreTests {
    @Test func parsesSimulatedCaptureCommand() throws {
        let command = try CommandParser.parse(arguments: [
            "capture",
            "--backend", "simulated",
            "--preset", "low-light",
            "--output", "/tmp/example.jpg",
        ])

        #expect(command == .capture(CaptureRequest(
            outputPath: "/tmp/example.jpg",
            backend: .simulated,
            cameraSelector: nil,
            preview: false,
            delaySeconds: 0,
            preset: .lowLight
        )))
    }

    @Test func rejectsPreviewForSimulatedBackend() throws {
        #expect(throws: CameraCaptureError.unsupported("--preview is only supported with --backend real")) {
            try CommandParser.parse(arguments: [
                "capture",
                "--backend", "simulated",
                "--preview",
            ])
        }
    }

    @Test func parsesPreviewCommand() throws {
        let command = try CommandParser.parse(arguments: [
            "preview",
            "--camera", "Test Camera",
            "--seconds", "12",
        ])

        #expect(command == .preview(PreviewRequest(
            cameraSelector: "Test Camera",
            seconds: 12,
            stayOpen: false
        )))
    }

    @Test func previewHelpIncludesDescriptionAndExamples() {
        let controller = AppController(dependencies: .testDefault())
        let output = controller.run(arguments: ["preview", "--help"])

        #expect(output.exitCode == 2)
        let help = output.stderr.joined(separator: "\n")
        #expect(help.contains("Description:"))
        #expect(help.contains("Examples:"))
        #expect(help.contains("camera-capture preview --stay-open"))
        #expect(help.contains("<camera-name>"))
        #expect(help.contains("<camera-id>"))
        #expect(help.contains("\"<camera-name>\""))
        #expect(help.contains("\"<camera-id>\""))
    }

    @Test func generalHelpUsesPlaceholderCameraNames() {
        let help = CommandParser.usageText

        #expect(help.contains("\"<camera-name>\""))
        #expect(!help.contains("FaceTime"))
    }

    @Test func rejectsMutuallyExclusivePreviewTimingOptions() throws {
        #expect(throws: CameraCaptureError.unsupported("--seconds and --stay-open are mutually exclusive for preview")) {
            try CommandParser.parse(arguments: [
                "preview",
                "--seconds", "5",
                "--stay-open",
            ])
        }
    }

    @Test func resolvesTimestampedOutputPath() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)

        let resolver = OutputPathResolver(
            fileManager: .default,
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            homeDirectory: { temporaryRoot }
        )
        let url = try resolver.resolve(path: nil, currentDirectory: temporaryRoot)
        #expect(url.path.contains("/Pictures/Camera Capture/"))
        #expect(url.path.hasSuffix(".jpg"))
    }

    @Test func refusesToOverwriteExistingOutput() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let target = temporaryRoot.appendingPathComponent("existing.jpg")
        try Data("content".utf8).write(to: target)

        let resolver = OutputPathResolver()
        #expect(throws: CameraCaptureError.fileExists(target)) {
            try resolver.resolve(path: target.path, currentDirectory: temporaryRoot)
        }
    }

    @Test func listPresetsPrintsAllPresets() {
        let controller = AppController(dependencies: .testDefault())
        let output = controller.run(arguments: ["list-presets"])

        #expect(output.exitCode == 0)
        #expect(output.stdout.contains("balanced"))
        #expect(output.stdout.contains("write-failure"))
    }

    @Test func simulatedCaptureWritesDeterministicJpeg() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)

        let dependencies = AppDependencies.testDefault(currentDirectory: temporaryRoot)
        let controller = AppController(dependencies: dependencies)
        let output = controller.run(arguments: ["capture", "--backend", "simulated", "--preset", "balanced"])

        #expect(output.exitCode == 0)
        let path = try #require(output.stdout.first)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(data.starts(with: [0xFF, 0xD8, 0xFF]))
    }

    @Test func simulatedFailurePresetMapsToWriteErrorExitCode() {
        let controller = AppController(dependencies: .testDefault())
        let output = controller.run(arguments: [
            "capture",
            "--backend", "simulated",
            "--preset", "write-failure",
        ])

        #expect(output.exitCode == 6)
        #expect(output.stderr.first?.contains("write failure") == true)
    }

    @Test func realCaptureDelegatesToHelperTransport() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)

        let probe = RealCaptureProbe()
        let dependencies = AppDependencies.testDefault(
            currentDirectory: temporaryRoot,
            realCaptureInvokerFactory: { probe }
        )
        let controller = AppController(dependencies: dependencies)

        let output = controller.run(arguments: [
            "capture",
            "--backend", "real",
            "--camera", "Test Camera",
            "--delay", "1.5",
        ])

        #expect(output.exitCode == 0)
        #expect(probe.capturedOptions?.backend == .real)
        #expect(probe.capturedOptions?.cameraSelector == "Test Camera")
        #expect(probe.capturedOptions?.delaySeconds == 1.5)
    }

    @Test func requestAccessUsesRealHelperInvoker() {
        let controller = AppController(
            dependencies: .testDefault(
                accessService: PermissionProbe(result: .restricted),
                realAccessInvokerFactory: { RealAccessProbe(result: .granted) }
            )
        )
        let output = controller.run(arguments: ["request-access"])

        #expect(output.exitCode == 0)
        #expect(output.stdout == ["granted"])
    }

    @Test func previewDelegatesToHelperInvoker() {
        let probe = RealPreviewProbe()
        let controller = AppController(dependencies: .testDefault(realPreviewInvokerFactory: { probe }))
        let output = controller.run(arguments: ["preview", "--camera", "Test Camera", "--stay-open"])

        #expect(output.exitCode == 0)
        #expect(output.stdout == ["preview closed"])
        #expect(probe.capturedRequest == PreviewRequest(cameraSelector: "Test Camera", seconds: nil, stayOpen: true))
    }

    @Test func previewRequestEnvelopeIncludesCancelFile() throws {
        let temp = try temporaryDirectory()
        let transport = TransportProbe()
        let invoker = HelperRealPreviewInvoker(transport: transport, temporaryDirectory: temp)

        try invoker.preview(request: PreviewRequest(cameraSelector: "Test Camera", seconds: nil, stayOpen: true))

        #expect(transport.lastRequest?.action == .preview)
        #expect(transport.lastRequest?.cancelFile?.hasSuffix("cancel.signal") == true)
    }

    @Test func helperLocatorPrefersExecutableOverride() throws {
        let root = try temporaryDirectory()
        let override = root.appendingPathComponent("override-helper")
        try makeExecutable(at: override)

        let resolved = try HelperLocator.resolve(
            environment: ["CAMERA_CAPTURE_HELPER_PATH": override.path],
            currentExecutable: root.appendingPathComponent("camera-capture"),
            fileManager: .default,
            homeDirectory: root
        )

        #expect(resolved == .executable(override))
    }

    @Test func helperLocatorUsesApplicationsBundleBeforeDevFallback() throws {
        let root = try temporaryDirectory()
        let installedApp = root
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent(HelperLocator.helperAppName, isDirectory: true)
        try FileManager.default.createDirectory(at: installedApp, withIntermediateDirectories: true)

        let devExecutable = root
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(HelperLocator.helperExecutableName)
        try makeExecutable(at: devExecutable)

        let resolved = try HelperLocator.resolve(
            environment: [:],
            currentExecutable: root.appendingPathComponent("bin/camera-capture"),
            fileManager: .default,
            homeDirectory: root
        )

        #expect(resolved == .appBundle(installedApp))
    }

    @Test func helperLocatorFallsBackToSiblingBundle() throws {
        let root = try temporaryDirectory()
        let siblingBundle = root
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(HelperLocator.helperAppName, isDirectory: true)
        try FileManager.default.createDirectory(at: siblingBundle, withIntermediateDirectories: true)

        let resolved = try HelperLocator.resolve(
            environment: [:],
            currentExecutable: root.appendingPathComponent("bin/camera-capture"),
            fileManager: .default,
            homeDirectory: root.appendingPathComponent("home", isDirectory: true)
        )

        #expect(resolved == .appBundle(siblingBundle))
    }

    @Test func appBundleTransportLaunchesViaOpenAndReadsResponse() throws {
        let runner = CommandRunnerProbe()
        let temp = try temporaryDirectory()
        let responsePath = temp.appendingPathComponent("response.json")
        let response = HelperResponseEnvelope(success: true, permissionState: .granted, message: BuildInfo.sharedVersion)
        try JSONEncoder().encode(response).write(to: responsePath)

        let transport = AppBundleHelperTransport(
            appURL: URL(fileURLWithPath: "/tmp/Camera Capture Helper.app"),
            runner: runner
        )
        let envelope = HelperRequestEnvelope(action: .requestAccess, responseFile: responsePath.path)
        let decoded = try transport.send(request: envelope)

        #expect(decoded.permissionState == PermissionState.granted)
        #expect(runner.lastExecutable?.path == "/usr/bin/open")
        #expect(runner.lastArguments?.contains("--request-file") == true)
        #expect(runner.lastArguments?.contains("/tmp/Camera Capture Helper.app") == true)
    }

    @Test func appBundleTransportFailsDeterministicallyWhenResponseMissing() throws {
        let runner = CommandRunnerProbe()
        let temp = try temporaryDirectory()
        let responsePath = temp.appendingPathComponent("response.json")

        let transport = AppBundleHelperTransport(
            appURL: URL(fileURLWithPath: "/tmp/Camera Capture Helper.app"),
            runner: runner
        )
        let envelope = HelperRequestEnvelope(action: .preview, responseFile: responsePath.path)

        #expect(throws: CameraCaptureError.helperFailed("helper did not produce a response file at \(responsePath.path)")) {
            try transport.send(request: envelope)
        }
    }
}

private final class RealCaptureProbe: RealCaptureInvoking, @unchecked Sendable {
    var capturedOptions: CaptureOptions?

    func capture(options: CaptureOptions) throws -> URL {
        capturedOptions = options
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: options.outputURL)
        return options.outputURL
    }
}

private final class RealPreviewProbe: RealPreviewInvoking, @unchecked Sendable {
    var capturedRequest: PreviewRequest?

    func preview(request: PreviewRequest) throws {
        capturedRequest = request
    }
}

private struct RealAccessProbe: RealAccessInvoking {
    let result: PermissionState

    func requestAccess() throws -> PermissionState {
        result
    }
}

private struct PermissionProbe: AccessRequesting {
    let result: PermissionState

    func requestAccess() throws -> PermissionState {
        result
    }
}

private final class TransportProbe: HelperTransporting, @unchecked Sendable {
    var lastRequest: HelperRequestEnvelope?

    func send(request: HelperRequestEnvelope) throws -> HelperResponseEnvelope {
        lastRequest = request
        return HelperResponseEnvelope(success: true, message: BuildInfo.sharedVersion)
    }
}

private struct DeviceProbe: DeviceListing {
    func listDevices() throws -> [CameraDevice] {
        [CameraDevice(id: "sim-device", name: "Synthetic Camera")]
    }
}

private final class CommandRunnerProbe: CommandRunning, @unchecked Sendable {
    var lastExecutable: URL?
    var lastArguments: [String]?
    var result = CommandResult(terminationStatus: 0, stdout: "", stderr: "")

    func run(executable: URL, arguments: [String]) throws -> CommandResult {
        lastExecutable = executable
        lastArguments = arguments
        return result
    }
}

private extension AppDependencies {
    static func testDefault(
        currentDirectory: URL = FileManager.default.temporaryDirectory,
        accessService: any AccessRequesting = PermissionProbe(result: .granted),
        realCaptureInvokerFactory: @escaping @Sendable () throws -> any RealCaptureInvoking = { RealCaptureProbe() },
        realPreviewInvokerFactory: @escaping @Sendable () throws -> any RealPreviewInvoking = { RealPreviewProbe() },
        realAccessInvokerFactory: @escaping @Sendable () throws -> any RealAccessInvoking = { RealAccessProbe(result: .granted) }
    ) -> AppDependencies {
        AppDependencies(
            currentDirectory: currentDirectory,
            outputPathResolver: OutputPathResolver(
                fileManager: .default,
                now: { Date(timeIntervalSince1970: 1_700_000_000) },
                homeDirectory: { currentDirectory }
            ),
            deviceService: DeviceProbe(),
            accessService: accessService,
            simulatedCaptureService: SimulatedCaptureService(),
            realCaptureInvokerFactory: realCaptureInvokerFactory,
            realPreviewInvokerFactory: realPreviewInvokerFactory,
            realAccessInvokerFactory: realAccessInvokerFactory
        )
    }
}

private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeExecutable(at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}
