import CameraCaptureCore
import Foundation

let executableURL = URL(fileURLWithPath: CommandLine.arguments.first ?? "camera-capture")
let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

let dependencies = AppDependencies(
    currentDirectory: currentDirectory,
    outputPathResolver: OutputPathResolver(),
    deviceService: RealCameraDeviceService(),
    accessService: CameraAccessService(),
    simulatedCaptureService: SimulatedCaptureService(),
    realCaptureInvokerFactory: {
        let target = try HelperLocator.resolve(currentExecutable: executableURL)
        let transport = HelperLocator.makeTransport(target: target)
        return HelperRealCaptureInvoker(transport: transport)
    },
    realPreviewInvokerFactory: {
        let target = try HelperLocator.resolve(currentExecutable: executableURL)
        let transport = HelperLocator.makeTransport(target: target)
        return HelperRealPreviewInvoker(transport: transport)
    },
    realAccessInvokerFactory: {
        let target = try HelperLocator.resolve(currentExecutable: executableURL)
        let transport = HelperLocator.makeTransport(target: target)
        return HelperRealAccessInvoker(transport: transport)
    }
)

let controller = AppController(dependencies: dependencies)
let output = controller.run(arguments: Array(CommandLine.arguments.dropFirst()))
for line in output.stdout {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}
for line in output.stderr {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}
exit(output.exitCode)
