import Foundation

public struct GitProcessResult: Sendable {
    public let output: Data
    public let errorOutput: Data
    public let exitCode: Int32

    public var text: String { String(decoding: output, as: UTF8.self) }
    public var errorText: String { String(decoding: errorOutput, as: UTF8.self) }
}

public struct GitProcess: Sendable {
    public let executableURL: URL
    public let outputLimit: Int

    public init(executableURL: URL? = nil, outputLimit: Int = 64 * 1024 * 1024) {
        self.executableURL = executableURL ?? Self.defaultExecutableURL
        self.outputLimit = outputLimit
    }

    public static var defaultExecutableURL: URL {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appending(path: "git/bin/git")
            if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        }
        return URL(fileURLWithPath: "/usr/bin/git")
    }

    public func run(
        in directory: URL,
        _ arguments: [String],
        acceptedExitCodes: Set<Int32> = [0]
    ) throws -> GitProcessResult {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "gitdesk-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let outputURL = temporaryDirectory.appending(path: "stdout")
        let errorURL = temporaryDirectory.appending(path: "stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = directory
        process.arguments = arguments
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw GitDeskError.commandFailed(-1, "Could not launch Git: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        try outputHandle.synchronize()
        try errorHandle.synchronize()

        let outputSize = (try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue ?? 0
        let errorSize = (try FileManager.default.attributesOfItem(atPath: errorURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard outputSize <= outputLimit, errorSize <= outputLimit else {
            throw GitDeskError.outputTooLarge
        }

        let result = GitProcessResult(
            output: try Data(contentsOf: outputURL),
            errorOutput: try Data(contentsOf: errorURL),
            exitCode: process.terminationStatus
        )
        guard acceptedExitCodes.contains(result.exitCode) else {
            let detail = result.errorText.trimmingCharacters(in: .whitespacesAndNewlines)
            throw GitDeskError.commandFailed(
                result.exitCode,
                detail.isEmpty ? "Git exited with code \(result.exitCode)." : detail
            )
        }
        return result
    }
}
