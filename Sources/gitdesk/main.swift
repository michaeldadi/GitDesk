import AppKit
import Foundation
import GitDeskCore

@main
struct GitDeskCLI {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("gitdesk: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty || arguments.contains("--help") {
            print(usage)
            return
        }

        var repositoryPath = FileManager.default.currentDirectoryPath
        if let index = arguments.firstIndex(of: "--repo") {
            guard index + 1 < arguments.count else {
                throw GitDeskError.invalidInput("--repo requires a path.")
            }
            repositoryPath = arguments[index + 1]
            arguments.removeSubrange(index...index + 1)
        }
        guard let command = arguments.first else {
            throw GitDeskError.invalidInput("Choose a command.")
        }
        let parameters = Array(arguments.dropFirst())

        if command == "clone" {
            guard parameters.count == 2 else {
                throw GitDeskError.invalidInput("Usage: gitdesk clone <remote> <directory>")
            }
            try GitRepository.clone(
                remote: parameters[0],
                destination: URL(fileURLWithPath: parameters[1], isDirectory: true)
            )
            return
        }
        if command == "init" {
            guard parameters.count == 1 else {
                throw GitDeskError.invalidInput("Usage: gitdesk init <directory>")
            }
            try GitRepository.create(at: URL(fileURLWithPath: parameters[0], isDirectory: true))
            return
        }
        if command == "open" {
            var view: GitDeskView = .changes
            if let index = parameters.firstIndex(of: "--view") {
                guard index + 1 < parameters.count,
                      let requested = GitDeskView(rawValue: parameters[index + 1]) else {
                    throw GitDeskError.invalidInput("Use --view changes|history|stashes|worktrees.")
                }
                view = requested
            }
            let link = try GitDeskLink(
                repository: URL(fileURLWithPath: repositoryPath, isDirectory: true), view: view
            )
            guard NSWorkspace.shared.open(link.url) else {
                throw GitDeskError.invalidInput("GitDesk.app is not registered to open links. Launch the app once, then retry.")
            }
            return
        }

        let repository = try GitRepository(
            location: URL(fileURLWithPath: repositoryPath, isDirectory: true)
        )
        switch command {
        case "status":
            let snapshot = try await repository.snapshot()
            print(snapshot.branch)
            for entry in snapshot.entries { print("\(entry.code)  \(entry.path)") }
        case "history":
            let commits = try await repository.history(
                limit: parameters.first.flatMap(Int.init) ?? 30
            )
            for commit in commits {
                print("\(commit.id.prefix(8))  \(commit.subject)")
            }
        case "diff":
            guard let path = parameters.first else {
                throw GitDeskError.invalidInput("Usage: gitdesk diff <path> [--staged]")
            }
            print(try await repository.diff(
                path: path, staged: parameters.contains("--staged")
            ), terminator: "")
        case "stage":
            try await repository.stage(paths: parameters)
        case "unstage":
            try await repository.unstage(paths: parameters)
        case "commit":
            guard !parameters.isEmpty else {
                throw GitDeskError.invalidInput("Usage: gitdesk commit <message> [--amend]")
            }
            try await repository.commit(
                message: parameters.filter { $0 != "--amend" }.joined(separator: " "),
                amend: parameters.contains("--amend")
            )
        case "branch":
            if parameters.isEmpty || parameters[0] == "list" {
                for branch in try await repository.branches() { print(branch) }
            } else if parameters[0] == "create", parameters.count == 2 {
                try await repository.createBranch(parameters[1])
            } else if parameters[0] == "switch", parameters.count == 2 {
                try await repository.checkout(parameters[1])
            } else {
                throw GitDeskError.invalidInput("Usage: gitdesk branch [list|create <name>|switch <name>]")
            }
        case "fetch":
            try await repository.fetch()
        case "pull":
            try await repository.pull()
        case "push":
            try await repository.push()
        case "stash":
            if parameters.isEmpty || parameters[0] == "list" {
                for stash in try await repository.stashes() { print(stash) }
            } else if parameters[0] == "save" {
                try await repository.stash(message: parameters.dropFirst().joined(separator: " "))
            } else if parameters[0] == "apply", parameters.count == 2 {
                try await repository.applyStash(parameters[1])
            } else {
                throw GitDeskError.invalidInput("Usage: gitdesk stash [list|save [message]|apply <ref>]")
            }
        case "worktree":
            if parameters.isEmpty || parameters[0] == "list" {
                for worktree in try await repository.worktrees() {
                    print("\(worktree.displayName)\t\(worktree.path)")
                }
            } else if parameters[0] == "create", parameters.count == 3 {
                try await repository.createWorktree(
                    at: URL(fileURLWithPath: parameters[2], isDirectory: true),
                    newBranch: parameters[1]
                )
            } else {
                throw GitDeskError.invalidInput("Usage: gitdesk worktree [list|create <branch> <directory>]")
            }
        default:
            throw GitDeskError.invalidInput("Unknown command: \(command)")
        }
    }

    private static let usage = """
        GitDesk — a native Git workspace

        Usage: gitdesk [--repo <path>] <command> [arguments]

        Commands:
          status                         Show working-copy changes
          open [--view <view>]           Open repository in the desktop app
          history [count]                Show recent commits
          diff <path> [--staged]         Show a file diff
          stage <paths...>               Stage files
          unstage <paths...>             Unstage files
          commit <message> [--amend]     Commit staged changes
          branch [list|create|switch]   Manage local branches
          fetch | pull | push            Synchronize remotes
          stash [list|save|apply]        Manage stashes
          worktree [list|create]         List or create worktrees
          clone <remote> <directory>     Clone a repository
          init <directory>               Create a repository
        """
}
