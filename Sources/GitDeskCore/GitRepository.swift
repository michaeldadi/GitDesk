import Foundation

public actor GitRepository {
    public let location: URL
    private let process: GitProcess

    public init(location: URL, process: GitProcess = GitProcess()) throws {
        let resolved = location.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GitDeskError.invalidRepository(resolved.path)
        }
        _ = try process.run(in: resolved, ["rev-parse", "--git-dir"])
        self.location = resolved
        self.process = process
    }

    public func snapshot() throws -> GitRepositorySnapshot {
        let result = try process.run(in: location, [
            "status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all"
        ])
        let branch = GitStatusParser.branch(from: result.output) ?? "Unknown branch"
        return GitRepositorySnapshot(branch: branch, entries: GitStatusParser.parse(result.output))
    }

    public func branchName() throws -> String {
        let symbolic = try process.run(
            in: location, ["symbolic-ref", "--quiet", "--short", "HEAD"],
            acceptedExitCodes: [0, 1]
        )
        if symbolic.exitCode == 0 {
            return symbolic.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let detached = try process.run(in: location, ["rev-parse", "--short", "HEAD"])
        return "Detached at " + detached.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func history(limit: Int = 200, skip: Int = 0) throws -> [GitCommit] {
        guard (1...2_000).contains(limit), skip >= 0 else {
            throw GitDeskError.invalidInput("Invalid history range.")
        }
        let result = try process.run(
            in: location,
            ["log", "--max-count=\(limit)", "--skip=\(skip)",
             "--pretty=format:%H%x1f%an%x1f%aI%x1f%s%x1e"],
            acceptedExitCodes: [0, 128]
        )
        if result.exitCode == 128 && result.errorText.contains("does not have any commits") {
            return []
        }
        if result.exitCode != 0 {
            throw GitDeskError.commandFailed(result.exitCode, result.errorText)
        }
        let formatter = ISO8601DateFormatter()
        return result.text.split(separator: "\u{1e}").compactMap { row in
            let fields = row.split(separator: "\u{1f}", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4 else { return nil }
            return GitCommit(
                id: String(fields[0]), author: String(fields[1]),
                date: formatter.date(from: String(fields[2])), subject: String(fields[3])
            )
        }
    }

    public func diff(path: String, staged: Bool = false) throws -> String {
        var arguments = ["diff", "--no-ext-diff", "--no-textconv", "--no-color"]
        if staged { arguments.append("--cached") }
        arguments += ["--", path]
        return try process.run(in: location, arguments).text
    }

    public func untrackedDiff(path: String) throws -> String {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.components(separatedBy: "/").contains("..") else {
            throw GitDeskError.invalidInput("Invalid repository path.")
        }
        let file = location.appending(path: path)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw GitDeskError.invalidInput("This file no longer exists. Refresh the repository.")
        }
        return try process.run(
            in: location, ["diff", "--no-index", "--no-ext-diff", "--no-color", "--", "/dev/null", file.path],
            acceptedExitCodes: [0, 1]
        ).text
    }

    public func commitDetails(id: String) throws -> String {
        guard (40...64).contains(id.count),
              id.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) else {
            throw GitDeskError.invalidInput("Invalid commit ID.")
        }
        return try process.run(
            in: location, ["show", "--format=fuller", "--stat", "--no-color", id]
        ).text
    }

    public func stage(paths: [String]) throws {
        guard !paths.isEmpty else { return }
        _ = try process.run(in: location, ["add", "--"] + paths)
    }

    public func unstage(paths: [String]) throws {
        guard !paths.isEmpty else { return }
        let head = try process.run(
            in: location, ["rev-parse", "--verify", "HEAD"],
            acceptedExitCodes: [0, 128]
        )
        if head.exitCode == 0 {
            _ = try process.run(in: location, ["restore", "--staged", "--"] + paths)
        } else {
            _ = try process.run(in: location, ["rm", "--cached", "--"] + paths)
        }
    }

    public func commit(message: String, amend: Bool = false) throws {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitDeskError.invalidInput("Enter a commit message.")
        }
        var args = ["commit", "-m", trimmed]
        if amend { args.append("--amend") }
        _ = try process.run(in: location, args)
    }

    public func branches() throws -> [String] {
        let result = try process.run(
            in: location, ["for-each-ref", "--format=%(refname:short)", "refs/heads"]
        )
        return result.text.split(whereSeparator: \.isNewline).map(String.init)
    }

    public func createBranch(_ name: String, checkout: Bool = true) throws {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.contains("\0") else {
            throw GitDeskError.invalidInput("Invalid branch name.")
        }
        _ = try process.run(in: location, ["check-ref-format", "--branch", name])
        _ = try process.run(in: location, checkout ? ["switch", "-c", name] : ["branch", name])
    }

    public func checkout(_ name: String) throws {
        guard !name.hasPrefix("-") else { throw GitDeskError.invalidInput("Invalid branch name.") }
        _ = try process.run(in: location, ["switch", name])
    }

    public func fetch() throws {
        _ = try process.run(in: location, ["fetch", "--all", "--prune"])
    }

    public func pull() throws {
        _ = try process.run(in: location, ["pull", "--ff-only"])
    }

    public func push() throws {
        _ = try process.run(in: location, ["push"])
    }

    public func stashes() throws -> [String] {
        let result = try process.run(in: location, ["stash", "list", "--format=%gd %s"])
        return result.text.split(whereSeparator: \.isNewline).map(String.init)
    }

    public func stash(message: String? = nil) throws {
        var args = ["stash", "push", "--include-untracked"]
        if let message, !message.isEmpty { args += ["-m", message] }
        _ = try process.run(in: location, args)
    }

    public func applyStash(_ reference: String) throws {
        guard reference.hasPrefix("stash@{") else {
            throw GitDeskError.invalidInput("Invalid stash reference.")
        }
        _ = try process.run(in: location, ["stash", "apply", reference])
    }

    public func worktrees() throws -> [GitWorktree] {
        let result = try process.run(in: location, ["worktree", "list", "--porcelain", "-z"])
        return GitWorktreeParser.parse(result.output)
    }

    public func createWorktree(at destination: URL, newBranch: String) throws {
        guard !newBranch.isEmpty, !newBranch.hasPrefix("-"), !newBranch.contains("\0") else {
            throw GitDeskError.invalidInput("Invalid branch name.")
        }
        _ = try process.run(in: location, ["check-ref-format", "--branch", newBranch])
        let target = destination.standardizedFileURL
        guard !FileManager.default.fileExists(atPath: target.path),
              FileManager.default.fileExists(atPath: target.deletingLastPathComponent().path) else {
            throw GitDeskError.invalidInput("Choose a new worktree folder in an existing location.")
        }
        _ = try process.run(in: location, ["worktree", "add", "-b", newBranch, target.path, "HEAD"])
    }

    public static func clone(remote: String, destination: URL, process: GitProcess = GitProcess()) throws {
        guard !remote.isEmpty, !remote.hasPrefix("-") else {
            throw GitDeskError.invalidInput("Invalid remote URL.")
        }
        let parent = destination.deletingLastPathComponent()
        _ = try process.run(in: parent, ["clone", "--", remote, destination.lastPathComponent])
    }

    public static func create(at location: URL, process: GitProcess = GitProcess()) throws {
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        _ = try process.run(in: location, ["init"])
    }
}
