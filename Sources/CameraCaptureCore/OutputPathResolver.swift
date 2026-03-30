import Foundation

public struct OutputPathResolver {
    public var fileManager: FileManager
    public var now: @Sendable () -> Date
    public var homeDirectory: @Sendable () -> URL

    public init(
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        homeDirectory: @escaping @Sendable () -> URL = {
            FileManager.default.homeDirectoryForCurrentUser
        }
    ) {
        self.fileManager = fileManager
        self.now = now
        self.homeDirectory = homeDirectory
    }

    public func resolve(path: String?, currentDirectory: URL) throws -> URL {
        let outputURL: URL
        if let path, path.isEmpty == false {
            let candidate = URL(fileURLWithPath: path, relativeTo: currentDirectory)
            outputURL = candidate.standardizedFileURL
        } else {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

            let filename = "\(formatter.string(from: now())).jpg"
            let picturesRoot = homeDirectory().appendingPathComponent("Pictures", isDirectory: true)
            outputURL = picturesRoot
                .appendingPathComponent("Camera Capture", isDirectory: true)
                .appendingPathComponent(filename, isDirectory: false)
                .standardizedFileURL
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            throw CameraCaptureError.fileExists(outputURL)
        }

        let directory = outputURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return outputURL
    }
}
