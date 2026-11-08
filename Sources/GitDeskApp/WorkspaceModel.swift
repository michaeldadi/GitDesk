import Foundation
import GitDeskCore
import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case workingCopy = "Changes"
    case history = "History"
    case stashes = "Stashes"
    case worktrees = "Worktrees"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .workingCopy: "square.stack.3d.up"
        case .history: "point.3.connected.trianglepath.dotted"
        case .stashes: "archivebox"
        case .worktrees: "arrow.triangle.branch"
        }
    }
}

@MainActor
final class WorkspaceModel: ObservableObject {
    @Published var repositories: [SavedRepository] = []
    @Published var selectedRepositoryPath: String?
    @Published var section: WorkspaceSection = .workingCopy
    @Published var snapshot: GitRepositorySnapshot?
    @Published var commits: [GitCommit] = []
    @Published var stashes: [String] = []
    @Published var worktrees: [GitWorktree] = []
    @Published var historyHasMore = false
    @Published var branches: [String] = []
    @Published var selectedFile: String?
    @Published var selectedCommitID: String?
    @Published var detail = ""
    @Published var commitMessage = ""
    @Published var isBusy = false
    @Published var errorMessage: String?

    private var library: RepositoryLibrary?
    private var currentRepository: GitRepository?
    private var loadGeneration = 0

    init() {
        do {
            let library = try RepositoryLibrary()
            self.library = library
            repositories = try library.all()
            if let first = repositories.first {
                selectRepository(first.path)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var selectedRepositoryName: String {
        repositories.first(where: { $0.path == selectedRepositoryPath })?.name ?? "GitDesk"
    }

    var selectedCommit: GitCommit? {
        commits.first(where: { $0.id == selectedCommitID })
    }

    func addRepository(_ url: URL) {
        do {
            try library?.add(url)
            repositories = try library?.all() ?? []
            selectRepository(url.standardizedFileURL.resolvingSymlinksInPath().path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectRepository(_ path: String?) {
        loadGeneration += 1
        selectedRepositoryPath = path
        selectedFile = nil
        selectedCommitID = nil
        detail = ""
        guard let path else {
            currentRepository = nil
            snapshot = nil
            commits = []
            worktrees = []
            return
        }
        do {
            currentRepository = try GitRepository(location: URL(fileURLWithPath: path))
            section = .workingCopy
            refresh()
        } catch {
            currentRepository = nil
            snapshot = nil
            errorMessage = error.localizedDescription
        }
    }

    func chooseSection(_ newSection: WorkspaceSection) {
        section = newSection
        selectedFile = nil
        selectedCommitID = nil
        detail = ""
        refresh()
    }

    func refresh() {
        guard let repository = currentRepository else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isBusy = true
        Task {
            do {
                let nextSnapshot = try await repository.snapshot()
                let nextBranches = try await repository.branches()
                let nextCommits = section == .history
                    ? try await repository.history(limit: 100) : []
                let nextStashes = section == .stashes
                    ? try await repository.stashes() : []
                let nextWorktrees = section == .worktrees
                    ? try await repository.worktrees() : []
                guard generation == loadGeneration else { return }
                snapshot = nextSnapshot
                branches = nextBranches
                if section == .history {
                    commits = nextCommits
                    historyHasMore = nextCommits.count == 100
                }
                if section == .stashes { stashes = nextStashes }
                if section == .worktrees { worktrees = nextWorktrees }
                isBusy = false
                if section == .workingCopy, let selectedFile {
                    selectFile(selectedFile)
                }
            } catch {
                guard generation == loadGeneration else { return }
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMoreHistory() {
        guard section == .history, historyHasMore,
              let repository = currentRepository, !isBusy else { return }
        let generation = loadGeneration
        let skip = commits.count
        isBusy = true
        Task {
            do {
                let page = try await repository.history(limit: 100, skip: skip)
                guard generation == loadGeneration, section == .history else { return }
                commits += page
                historyHasMore = page.count == 100
                isBusy = false
            } catch {
                guard generation == loadGeneration else { return }
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectFile(_ path: String?) {
        selectedFile = path
        selectedCommitID = nil
        detail = ""
        guard let path, let repository = currentRepository else { return }
        let repositoryPath = selectedRepositoryPath
        let isUntracked = snapshot?.entries.first(where: { $0.path == path })?.kind == .untracked
        Task {
            do {
                let unstaged = try await (isUntracked
                    ? repository.untrackedDiff(path: path) : repository.diff(path: path))
                let staged = try await repository.diff(path: path, staged: true)
                guard selectedFile == path, selectedRepositoryPath == repositoryPath else { return }
                if unstaged.isEmpty && staged.isEmpty {
                    detail = "No text diff is available for this file."
                } else {
                    detail = [
                        staged.isEmpty ? nil : "STAGED\n\n" + staged,
                        unstaged.isEmpty ? nil : "WORKING COPY\n\n" + unstaged,
                    ].compactMap { $0 }.joined(separator: "\n\n")
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectCommit(_ id: String?) {
        selectedCommitID = id
        selectedFile = nil
        detail = ""
        guard let id, let repository = currentRepository else { return }
        let repositoryPath = selectedRepositoryPath
        Task {
            do {
                let text = try await repository.commitDetails(id: id)
                guard selectedCommitID == id, selectedRepositoryPath == repositoryPath else { return }
                detail = text
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stage(_ path: String) {
        execute { try await $0.stage(paths: [path]) }
    }

    func unstage(_ path: String) {
        execute { try await $0.unstage(paths: [path]) }
    }

    func stageAll() {
        let paths = snapshot?.entries
            .filter { $0.kind != .ignored && ($0.isUnstaged || $0.kind == .untracked) }
            .map(\.path) ?? []
        execute { try await $0.stage(paths: paths) }
    }

    func commit() {
        let message = commitMessage
        guard let repository = currentRepository else { return }
        isBusy = true
        Task {
            do {
                try await repository.commit(message: message)
                commitMessage = ""
                refresh()
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func fetch() { execute { try await $0.fetch() } }
    func pull() { execute { try await $0.pull() } }
    func push() { execute { try await $0.push() } }
    func createBranch(_ name: String) { execute { try await $0.createBranch(name) } }
    func checkout(_ name: String) { execute { try await $0.checkout(name) } }
    func saveStash() { execute { try await $0.stash() } }

    func createWorktree(at destination: URL, branch: String) {
        guard let repository = currentRepository else { return }
        isBusy = true
        Task {
            do {
                try await repository.createWorktree(at: destination, newBranch: branch)
                addRepository(destination)
                chooseSection(.workingCopy)
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func execute(_ operation: @escaping @Sendable (GitRepository) async throws -> Void) {
        guard let repository = currentRepository else { return }
        isBusy = true
        Task {
            do {
                try await operation(repository)
                refresh()
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
