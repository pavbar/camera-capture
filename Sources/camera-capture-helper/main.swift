import AppKit
import AVFoundation
import CameraCaptureCore
import Dispatch
import Foundation

enum HelperCommandParser {
    static func parse(arguments: [String]) throws -> CLICommand {
        guard let subcommand = arguments.first else {
            throw CameraCaptureError.usage(helperUsageText)
        }

        switch subcommand {
        case "capture":
            var forwarded = ["capture"] + Array(arguments.dropFirst())
            if forwarded.contains("--backend") == false {
                forwarded += ["--backend", "real"]
            }
            return try CommandParser.parse(arguments: forwarded)
        case "preview", "request-access":
            return try CommandParser.parse(arguments: arguments)
        default:
            throw CameraCaptureError.usage(helperUsageText)
        }
    }

    static func requestFile(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--request-file"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static let helperUsageText = """
    Usage:
      camera-capture-helper capture --output <path> [--camera <id|name>] [--preview] [--delay <seconds>]
      camera-capture-helper preview [--camera <id|name>] [--seconds <seconds> | --stay-open]
      camera-capture-helper request-access
      camera-capture-helper --request-file <path>
    """
}

final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onComplete: (Result<Data, Error>) -> Void

    init(onComplete: @escaping (Result<Data, Error>) -> Void) {
        self.onComplete = onComplete
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            onComplete(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            onComplete(.failure(CameraCaptureError.writeFailure("failed to generate JPEG data from AVCapturePhoto")))
            return
        }
        onComplete(.success(data))
    }
}

final class PhotoDelegateStore {
    nonisolated(unsafe) private static var delegates: [UUID: PhotoDelegate] = [:]

    static func insert(_ delegate: PhotoDelegate, for token: UUID) {
        delegates[token] = delegate
    }

    static func remove(_ token: UUID) {
        delegates[token] = nil
    }
}

@MainActor
final class CaptureResultBox {
    var result: Result<Data, Error>?
}

@MainActor
final class PreviewWindowController: NSWindowController {
    init(layer: AVCaptureVideoPreviewLayer) {
        let frame = NSRect(x: 0, y: 0, width: 960, height: 640)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "camera-capture preview"
        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer = layer
        layer.frame = frame
        layer.videoGravity = .resizeAspectFill
        window.contentView = view
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
struct RealCaptureHelper {
    func runAuthorized(request: CaptureRequest) async throws -> String {
        let device = try resolveDevice(selector: request.cameraSelector)
        let session = AVCaptureSession()
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.helperFailed("unable to attach camera input")
        }
        session.addInput(input)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            throw CameraCaptureError.helperFailed("unable to attach photo output")
        }
        session.addOutput(output)
        session.commitConfiguration()

        var windowController: PreviewWindowController?
        if request.preview {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            windowController = PreviewWindowController(layer: previewLayer)
            windowController?.showWindow(nil)
            app.activate(ignoringOtherApps: true)
        }

        session.startRunning()
        if request.delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(request.delaySeconds * 1_000_000_000))
        } else if request.preview {
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        let resultBox = CaptureResultBox()
        let token = UUID()
        let delegate = PhotoDelegate { result in
            Task { @MainActor in
                resultBox.result = result
                PhotoDelegateStore.remove(token)
            }
        }
        PhotoDelegateStore.insert(delegate, for: token)
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)

        let deadline = Date(timeIntervalSinceNow: 15)
        while resultBox.result == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let jpegData: Data
        do {
            guard let result = resultBox.result else {
                throw CameraCaptureError.captureTimeout
            }
            jpegData = try result.get()
        } catch {
            session.stopRunning()
            windowController?.close()
            throw error
        }

        session.stopRunning()
        windowController?.close()

        guard let outputPath = request.outputPath else {
            throw CameraCaptureError.writeFailure("helper requires an explicit output path")
        }
        try jpegData.write(to: URL(fileURLWithPath: outputPath))
        return outputPath
    }

    func previewAuthorized(request: PreviewRequest, cancelFile: String?) throws {
        let device = try resolveDevice(selector: request.cameraSelector)
        let session = AVCaptureSession()
        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.helperFailed("unable to attach camera input")
        }
        session.addInput(input)
        session.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let windowController = PreviewWindowController(layer: previewLayer)
        windowController.showWindow(nil)
        app.activate(ignoringOtherApps: true)
        session.startRunning()

        let cancelURL = cancelFile.map(URL.init(fileURLWithPath:))

        if request.stayOpen {
            while windowController.window?.isVisible == true {
                if let cancelURL, FileManager.default.fileExists(atPath: cancelURL.path) {
                    break
                }
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
        } else {
            let deadline = Date(timeIntervalSinceNow: request.seconds ?? 10.0)
            while Date() < deadline {
                if let cancelURL, FileManager.default.fileExists(atPath: cancelURL.path) {
                    break
                }
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
        }

        session.stopRunning()
        windowController.close()
    }

    private func resolveDevice(selector: String?) throws -> AVCaptureDevice {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices

        if let selector {
            if let exact = devices.first(where: { $0.uniqueID == selector || $0.localizedName == selector }) {
                return exact
            }
            if let partial = devices.first(where: { $0.localizedName.localizedCaseInsensitiveContains(selector) }) {
                return partial
            }
            throw CameraCaptureError.cameraNotFound(selector)
        }

        guard let device = devices.first else {
            throw CameraCaptureError.helperFailed("no real camera devices available")
        }
        return device
    }
}

func requestCameraAccess() async -> PermissionState {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        return .granted
    case .denied:
        return .denied
    case .restricted:
        return .restricted
    case .notDetermined:
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { access in
                continuation.resume(returning: access)
            }
        }
        return granted ? .granted : .denied
    @unknown default:
        return .restricted
    }
}

func handleRequestFile(at path: String) async throws -> Int32 {
    let requestURL = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: requestURL)
    let envelope = try JSONDecoder().decode(HelperRequestEnvelope.self, from: data)
    let responseURL = URL(fileURLWithPath: envelope.responseFile)
    let helper = RealCaptureHelper()

    func writeFailureResponse(message: String, permissionState: PermissionState? = nil) throws -> Int32 {
        let response = HelperResponseEnvelope(
            success: false,
            permissionState: permissionState,
            message: message
        )
        try JSONEncoder().encode(response).write(to: responseURL)
        return 1
    }

    do {
        let response: HelperResponseEnvelope
        switch envelope.action {
        case .capture:
            guard let capture = envelope.capture else {
                throw CameraCaptureError.helperFailed("helper request missing capture payload")
            }
            let permissionState = await requestCameraAccess()
            guard permissionState == .granted else {
                throw CameraCaptureError.permissionDenied
            }
            let outputPath = try await helper.runAuthorized(request: capture)
            response = HelperResponseEnvelope(success: true, outputPath: outputPath, message: BuildInfo.sharedVersion)
        case .preview:
            guard let preview = envelope.preview else {
                throw CameraCaptureError.helperFailed("helper request missing preview payload")
            }
            let permissionState = await requestCameraAccess()
            guard permissionState == .granted else {
                throw CameraCaptureError.permissionDenied
            }
            try await helper.previewAuthorized(request: preview, cancelFile: envelope.cancelFile)
            response = HelperResponseEnvelope(success: true, message: BuildInfo.sharedVersion)
        case .requestAccess:
            let permissionState = await requestCameraAccess()
            response = HelperResponseEnvelope(success: true, permissionState: permissionState, message: BuildInfo.sharedVersion)
        }
        try JSONEncoder().encode(response).write(to: responseURL)
        return 0
    } catch let error as CameraCaptureError {
        return try writeFailureResponse(
            message: error.localizedDescription,
            permissionState: error == .permissionDenied ? .denied : nil
        )
    } catch {
        return try writeFailureResponse(message: String(describing: error))
    }
}

@main
final class HelperApp: NSObject, NSApplicationDelegate {
    private let arguments = Array(CommandLine.arguments.dropFirst())

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let exitCode = await run()
            Foundation.exit(exitCode)
        }
    }

    @MainActor
    private func run() async -> Int32 {
        var exitCode: Int32 = 0

        do {
            if let requestFile = HelperCommandParser.requestFile(arguments: arguments) {
                return try await handleRequestFile(at: requestFile)
            }

            let command = try HelperCommandParser.parse(arguments: arguments)
            let helper = RealCaptureHelper()
            switch command {
            case .capture(let request):
                let permissionState = await requestCameraAccess()
                guard permissionState == .granted else {
                    throw CameraCaptureError.permissionDenied
                }
                let output = try await helper.runAuthorized(request: request)
                FileHandle.standardOutput.write(Data((output + "\n").utf8))
            case .preview(let request):
                let permissionState = await requestCameraAccess()
                guard permissionState == .granted else {
                    throw CameraCaptureError.permissionDenied
                }
                try helper.previewAuthorized(request: request, cancelFile: nil)
                FileHandle.standardOutput.write(Data("preview closed\n".utf8))
            case .requestAccess:
                let status = await requestCameraAccess()
                FileHandle.standardOutput.write(Data((status.rawValue + "\n").utf8))
            default:
                throw CameraCaptureError.usage("helper only supports real preview, real capture, and request-access")
            }
        } catch let error as CameraCaptureError {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exitCode = 1
        } catch {
            FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
            exitCode = 1
        }

        return exitCode
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = HelperApp()
        app.delegate = delegate
        app.run()
    }
}
