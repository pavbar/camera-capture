import Foundation

public struct CommandOutput: Sendable, Equatable {
    public var stdout: [String]
    public var stderr: [String]
    public var exitCode: Int32

    public init(stdout: [String] = [], stderr: [String] = [], exitCode: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public struct AppDependencies {
    public let currentDirectory: URL
    public let outputPathResolver: OutputPathResolver
    public let deviceService: any DeviceListing
    public let simulatedCaptureService: any SimulatedCapturing
    public let realCaptureInvokerFactory: @Sendable () throws -> any RealCaptureInvoking
    public let realPreviewInvokerFactory: @Sendable () throws -> any RealPreviewInvoking
    public let realAccessInvokerFactory: @Sendable () throws -> any RealAccessInvoking

    public init(
        currentDirectory: URL,
        outputPathResolver: OutputPathResolver,
        deviceService: any DeviceListing,
        simulatedCaptureService: any SimulatedCapturing,
        realCaptureInvokerFactory: @escaping @Sendable () throws -> any RealCaptureInvoking,
        realPreviewInvokerFactory: @escaping @Sendable () throws -> any RealPreviewInvoking,
        realAccessInvokerFactory: @escaping @Sendable () throws -> any RealAccessInvoking
    ) {
        self.currentDirectory = currentDirectory
        self.outputPathResolver = outputPathResolver
        self.deviceService = deviceService
        self.simulatedCaptureService = simulatedCaptureService
        self.realCaptureInvokerFactory = realCaptureInvokerFactory
        self.realPreviewInvokerFactory = realPreviewInvokerFactory
        self.realAccessInvokerFactory = realAccessInvokerFactory
    }
}

public final class AppController {
    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public func run(arguments: [String]) -> CommandOutput {
        do {
            let command = try CommandParser.parse(arguments: arguments)
            switch command {
            case .listPresets:
                return CommandOutput(stdout: SimulatedPreset.allCases.map(\.rawValue))
            case .listDevices:
                let devices = try dependencies.deviceService.listDevices()
                let lines = devices.isEmpty
                    ? ["No real camera devices found."]
                    : devices.map { "\($0.id)\t\($0.name)" }
                return CommandOutput(stdout: lines)
            case .requestAccess:
                let status = try dependencies.realAccessInvokerFactory().requestAccess()
                return CommandOutput(stdout: [status.rawValue])
            case .preview(let request):
                try dependencies.realPreviewInvokerFactory().preview(request: request)
                return CommandOutput(stdout: ["preview closed"])
            case .capture(let request):
                return try capture(request: request)
            }
        } catch let error as CameraCaptureError {
            return CommandOutput(stderr: [error.localizedDescription], exitCode: exitCode(for: error))
        } catch {
            return CommandOutput(stderr: [String(describing: error)], exitCode: 1)
        }
    }

    private func capture(request: CaptureRequest) throws -> CommandOutput {
        let outputURL = try dependencies.outputPathResolver.resolve(
            path: request.outputPath,
            currentDirectory: dependencies.currentDirectory
        )
        let options = CaptureOptions(
            outputURL: outputURL,
            backend: request.backend,
            cameraSelector: request.cameraSelector,
            preview: request.preview,
            delaySeconds: request.delaySeconds,
            preset: request.preset
        )

        switch request.backend {
        case .simulated:
            let location = try dependencies.simulatedCaptureService.capture(options: options)
            return CommandOutput(stdout: [location.path])
        case .real:
            let location = try dependencies.realCaptureInvokerFactory().capture(options: options)
            return CommandOutput(stdout: [location.path])
        }
    }

    private func exitCode(for error: CameraCaptureError) -> Int32 {
        switch error {
        case .usage, .unsupported, .invalidValue:
            return 2
        case .permissionDenied:
            return 3
        case .cameraNotFound:
            return 4
        case .captureTimeout:
            return 5
        case .fileExists, .writeFailure:
            return 6
        case .helperNotFound, .helperFailed:
            return 7
        }
    }
}
