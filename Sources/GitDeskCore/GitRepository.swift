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
        let tracking = GitStatusParser.tracking(from: result.output)
        return GitRepositorySnapshot(
            branch: branch, entries: GitStatusParser.parse(result.output),
            upstream: tracking.upstream, ahead: tracking.ahead, behind: tracking.behind
        )
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

    public func history(limit: Int = 200, skip: Int = 0, path: String? = nil) throws -> [GitCommit] {
        guard (1...2_000).contains(limit), skip >= 0 else {
            throw GitDeskError.invalidInput("Invalid history range.")
        }
        var args = ["log", "--max-count=\(limit)", "--skip=\(skip)",
                    "--pretty=format:%H%x1f%an%x1f%aI%x1f%s%x1e"]
        if let path {
            guard !path.isEmpty, !path.hasPrefix("/") else {
                throw GitDeskError.invalidInput("Invalid file history path.")
            }
            args += ["--follow", "--", path]
        }
        let result = try process.run(
            in: location, args,
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

    public func patch(path: String, staged: Bool = false) throws -> GitPatch? {
        GitPatchParser.parse(try diff(path: path, staged: staged))
    }

    public func applyHunk(
        path: String, staged: Bool, hunkID: Int, expectedDiff: String
    ) throws {
        let current = try diff(path: path, staged: staged)
        guard current == expectedDiff else {
            throw GitDeskError.invalidInput("The diff changed. Refresh this file before staging a hunk.")
        }
        guard let patch = GitPatchParser.parse(current),
              patch.hunks.indices.contains(hunkID) else {
            throw GitDeskError.invalidInput("This hunk is no longer available.")
        }
        let selected = Data((patch.header + patch.hunks[hunkID].raw).utf8)
        var args = ["apply", "--cached"]
        if staged { args.append("--reverse") }
        _ = try process.run(in: location, args + ["--check"], input: selected)
        _ = try process.run(in: location, args, input: selected)
    }

    public func commitDetails(id: String) throws -> String {
        guard (40...64).contains(id.count),
              id.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) else {
            throw GitDeskError.invalidInput("Invalid commit ID.")
        }
        return try process.run(
            in: location, ["show", "--format=fuller", "--stat", "--patch",
                           "--no-ext-diff", "--no-textconv", "--no-color", id]
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

    public func branchReview(base: String) throws -> [GitBranchReview] {
        let names = try branches()
        guard names.contains(base) else {
            throw GitDeskError.invalidInput("The base branch no longer exists. Refresh branches.")
        }
        let merged = try process.run(
            in: location, ["for-each-ref", "--merged=refs/heads/\(base)",
                           "--format=%(refname:short)", "refs/heads"]
        ).text.split(whereSeparator: \.isNewline).map(String.init)
        let mergedSet = Set(merged)
        var worktreeByBranch: [String: String] = [:]
        for worktree in try worktrees() {
            if let branch = worktree.branch, worktreeByBranch[branch] == nil {
                worktreeByBranch[branch] = worktree.path
            }
        }
        let output = try process.run(in: location, [
            "for-each-ref", "--sort=-committerdate",
            "--format=%(refname:short)%00%(objectname)%00%(committerdate:iso8601-strict)%00%(subject)%00%(upstream:short)",
            "refs/heads"
        ]).text
        let formatter = ISO8601DateFormatter()
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\0", omittingEmptySubsequences: false)
            guard fields.count == 5 else { return nil }
            let name = String(fields[0])
            return GitBranchReview(
                name: name, head: String(fields[1]),
                lastCommit: formatter.date(from: String(fields[2])),
                subject: String(fields[3]),
                upstream: fields[4].isEmpty ? nil : String(fields[4]),
                isMergedIntoBase: mergedSet.contains(name),
                worktreePath: worktreeByBranch[name]
            )
        }
    }

    public func compareBranch(_ name: String, withBase base: String) throws -> GitBranchComparison {
        let names = try branches()
        guard names.contains(name), names.contains(base) else {
            throw GitDeskError.invalidInput("One of these branches no longer exists. Refresh branches.")
        }
        let output = try process.run(in: location, [
            "rev-list", "--left-right", "--count", "refs/heads/\(base)...refs/heads/\(name)"
        ]).text
        let counts = output.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        guard counts.count == 2 else {
            throw GitDeskError.invalidInput("Could not compare the selected branches.")
        }
        return GitBranchComparison(baseOnly: counts[0], branchOnly: counts[1])
    }

    public func branchRelationship(_ name: String? = nil) throws -> GitBranchRelationship {
        let branch = try resolveLocalBranch(name)
        let parent = try localConfigValue("branch.\(branch).gitdeskparent")
        let stackedValue = try localConfigValue("branch.\(branch).gitdeskstacked")
        guard stackedValue == nil || stackedValue == "true" || stackedValue == "false" else {
            throw GitDeskError.invalidInput("Invalid GitDesk stacked value for \(branch).")
        }
        return GitBranchRelationship(
            branch: branch, parent: parent, isStacked: stackedValue == "true"
        )
    }

    public func setBranchParent(_ parent: String?, for name: String? = nil) throws {
        let branch = try resolveLocalBranch(name)
        let key = "branch.\(branch).gitdeskparent"
        guard let parent else {
            // Clear the flag first so a failed second write cannot leave a stacked branch
            // without a parent.
            try unsetLocalConfig("branch.\(branch).gitdeskstacked")
            try unsetLocalConfig(key)
            return
        }
        let names = Set(try branches())
        guard names.contains(parent), parent != branch else {
            throw GitDeskError.invalidInput("Choose a different existing local parent branch.")
        }
        var ancestor = parent
        var visited: Set<String> = []
        while true {
            guard visited.insert(ancestor).inserted else {
                throw GitDeskError.invalidInput("Existing branch parent cycle must be resolved first.")
            }
            guard ancestor != branch else {
                throw GitDeskError.invalidInput("Branch parents cannot form a cycle.")
            }
            guard let next = try localConfigValue("branch.\(ancestor).gitdeskparent") else { break }
            guard names.contains(next) else {
                throw GitDeskError.invalidInput("An ancestor parent branch no longer exists.")
            }
            ancestor = next
        }
        _ = try process.run(in: location, ["config", "--local", "--replace-all", key, parent])
    }

    public func setBranchStacked(_ stacked: Bool, for name: String? = nil) throws {
        let relation = try branchRelationship(name)
        let key = "branch.\(relation.branch).gitdeskstacked"
        if stacked {
            guard let parent = relation.parent, Set(try branches()).contains(parent) else {
                throw GitDeskError.invalidInput("Set an existing parent branch before stacking.")
            }
            _ = try process.run(in: location, ["config", "--local", "--replace-all", key, "true"])
        } else {
            try unsetLocalConfig(key)
        }
    }

    private func resolveLocalBranch(_ name: String?) throws -> String {
        let branch: String
        if let name {
            branch = name
        } else {
            let current = try process.run(
                in: location, ["symbolic-ref", "--quiet", "--short", "HEAD"],
                acceptedExitCodes: [0, 1]
            )
            guard current.exitCode == 0 else {
                throw GitDeskError.invalidInput("Choose a local branch while HEAD is detached.")
            }
            branch = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard try branches().contains(branch) else {
            throw GitDeskError.invalidInput("The local branch no longer exists.")
        }
        return branch
    }

    private func localConfigValue(_ key: String) throws -> String? {
        let result = try process.run(
            in: location, ["config", "--local", "--get", key], acceptedExitCodes: [0, 1]
        )
        return result.exitCode == 0
            ? result.text.trimmingCharacters(in: .newlines) : nil
    }

    private func unsetLocalConfig(_ key: String) throws {
        _ = try process.run(
            in: location, ["config", "--local", "--unset-all", key],
            acceptedExitCodes: [0, 5]
        )
    }

    public func createBranch(_ name: String, checkout: Bool = true) throws {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.contains("\0") else {
            throw GitDeskError.invalidInput("Invalid branch name.")
        }
        _ = try process.run(in: location, ["check-ref-format", "--branch", name])
        _ = try process.run(in: location, checkout ? ["switch", "-c", name] : ["branch", name])
    }

    public func tags() throws -> [String] {
        let output = try process.run(in: location, [
            "for-each-ref", "--sort=refname", "--format=%(refname:short)", "refs/tags"
        ]).text
        return output.split(whereSeparator: \.isNewline).map(String.init)
    }

    public func createTag(_ name: String, message: String? = nil) throws {
        try validateRefName(name, prefix: "refs/tags/")
        var args = ["tag", "--no-sign"]
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["-a", "-m", message]
        }
        _ = try process.run(in: location, args + [name, "HEAD"])
    }

    public func deleteTag(_ name: String) throws {
        guard try tags().contains(name) else {
            throw GitDeskError.invalidInput("The tag no longer exists.")
        }
        _ = try process.run(in: location, ["tag", "--delete", name])
    }

    public func remotes() throws -> [String] {
        let output = try process.run(in: location, ["remote"]).text
        return output.split(whereSeparator: \.isNewline).map(String.init)
    }

    public func addRemote(name: String, url: String) throws {
        try validateRefName(name, prefix: "refs/remotes/")
        try Self.validateRemoteURL(url)
        _ = try process.run(in: location, ["remote", "add", name, url])
    }

    public func removeRemote(_ name: String) throws {
        guard try remotes().contains(name) else {
            throw GitDeskError.invalidInput("The remote no longer exists.")
        }
        _ = try process.run(in: location, ["remote", "remove", name])
    }

    private func validateRefName(_ name: String, prefix: String) throws {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.contains("\0") else {
            throw GitDeskError.invalidInput("Invalid reference name.")
        }
        _ = try process.run(in: location, ["check-ref-format", prefix + name])
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

    public func stashes() throws -> [GitStash] {
        let result = try process.run(in: location, ["stash", "list", "--format=%gd%x00%s"])
        return result.text.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\0", maxSplits: 1,
                                    omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return GitStash(reference: String(fields[0]), subject: String(fields[1]))
        }
    }

    public func stash(message: String? = nil) throws {
        var args = ["stash", "push", "--include-untracked"]
        if let message, !message.isEmpty { args += ["-m", message] }
        _ = try process.run(in: location, args)
    }

    public func applyStash(_ reference: String) throws {
        try validateStashReference(reference)
        _ = try process.run(in: location, ["stash", "apply", reference])
    }

    public func stashDiff(_ reference: String) throws -> String {
        try validateStashReference(reference)
        return try process.run(in: location, [
            "stash", "show", "--patch", "--include-untracked", "--no-ext-diff", "--no-color", reference
        ]).text
    }

    private func validateStashReference(_ reference: String) throws {
        guard reference.hasPrefix("stash@{"), reference.hasSuffix("}"),
              reference.dropFirst(7).dropLast().allSatisfy(\.isNumber),
              reference.count > 8 else {
            throw GitDeskError.invalidInput("Invalid stash reference.")
        }
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
        try validateRemoteURL(remote)
        let parent = destination.deletingLastPathComponent()
        _ = try process.run(in: parent, ["clone", "--", remote, destination.lastPathComponent])
    }

    private static func validateRemoteURL(_ remote: String) throws {
        guard !remote.isEmpty, !remote.hasPrefix("-") else {
            throw GitDeskError.invalidInput("Invalid remote URL.")
        }
        if let components = URLComponents(string: remote), components.password != nil {
            throw GitDeskError.invalidInput("Do not put a password or token in the remote URL. Use a credential helper instead.")
        }
    }

    public static func create(at location: URL, process: GitProcess = GitProcess()) throws {
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        _ = try process.run(in: location, ["init"])
    }
}
