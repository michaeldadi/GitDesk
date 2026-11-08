import Foundation
import GitDeskCore
import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case workingCopy = "Changes"
    case history = "History"
    case branches = "Branches"
    case stashes = "Stashes"
    case worktrees = "Worktrees"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .workingCopy: "square.stack.3d.up"
        case .history: "point.3.connected.trianglepath.dotted"
        case .branches: "arrow.triangle.branch"
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
    @Published var stashes: [GitStash] = []
    @Published var selectedStashReference: String?
    @Published var worktrees: [GitWorktree] = []
    @Published var historyHasMore = false
    @Published var branches: [String] = []
    @Published var tags: [String] = []
    @Published var remotes: [String] = []
    @Published var branchReview: [GitBranchReview] = []
    @Published var branchReviewBase: String?
    @Published var selectedReviewBranch: String?
    @Published var selectedFile: String?
    @Published var selectedCommitID: String?
    @Published var detail = ""
    @Published var stagedPatch: GitPatch?
    @Published var unstagedPatch: GitPatch?
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

    var selectedBranchReview: GitBranchReview? {
        branchReview.first(where: { $0.name == selectedReviewBranch })
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

    func createRepository(at destination: URL) {
        isBusy = true
        Task {
            do {
                try await Task.detached {
                    try GitRepository.create(at: destination)
                }.value
                addRepository(destination)
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func cloneRepository(remote: String, to destination: URL) {
        isBusy = true
        Task {
            do {
                try await Task.detached {
                    try GitRepository.clone(remote: remote, destination: destination)
                }.value
                addRepository(destination)
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectRepository(_ path: String?) {
        loadGeneration += 1
        selectedRepositoryPath = path
        selectedFile = nil
        selectedCommitID = nil
        selectedReviewBranch = nil
        selectedStashReference = nil
        detail = ""
        stagedPatch = nil
        unstagedPatch = nil
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
        selectedReviewBranch = nil
        selectedStashReference = nil
        detail = ""
        stagedPatch = nil
        unstagedPatch = nil
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
                let base = branchReviewBase.flatMap { nextBranches.contains($0) ? $0 : nil }
                    ?? (nextBranches.contains("main") ? "main" : nextBranches.first)
                let nextReview = section == .branches && base != nil
                    ? try await repository.branchReview(base: base!) : []
                let nextTags = section == .branches ? try await repository.tags() : []
                let nextRemotes = section == .branches ? try await repository.remotes() : []
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
                if section == .branches {
                    branchReviewBase = base
                    branchReview = nextReview
                    tags = nextTags
                    remotes = nextRemotes
                }
                if section == .stashes { stashes = nextStashes }
                if section == .worktrees { worktrees = nextWorktrees }
                isBusy = false
                if section == .workingCopy, let selectedFile {
                    selectFile(selectedFile)
                } else if section == .branches, let selectedReviewBranch {
                    selectReviewBranch(selectedReviewBranch)
                }
            } catch {
                guard generation == loadGeneration else { return }
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseReviewBase(_ branch: String) {
        branchReviewBase = branch
        selectedReviewBranch = nil
        detail = ""
        refresh()
    }

    func selectReviewBranch(_ name: String?) {
        selectedReviewBranch = name
        selectedFile = nil
        selectedCommitID = nil
        selectedStashReference = nil
        detail = ""
        stagedPatch = nil
        unstagedPatch = nil
        guard let name, let base = branchReviewBase,
              let branch = selectedBranchReview,
              let repository = currentRepository else { return }
        let repositoryPath = selectedRepositoryPath
        Task {
            do {
                let comparison = try await repository.compareBranch(name, withBase: base)
                let relationship = try await repository.branchRelationship(name)
                guard selectedReviewBranch == name,
                      selectedRepositoryPath == repositoryPath else { return }
                detail = """
                    \(name) compared with \(base)

                    \(comparison.branchOnly) commits on \(name)
                    \(comparison.baseOnly) commits on \(base)
                    \(branch.isMergedIntoBase ? "Merged into base" : "Not merged into base")

                    Latest commit: \(branch.subject)
                    Commit: \(branch.head)
                    Upstream: \(branch.upstream ?? "None")
                    Parent: \(relationship.parent ?? "None")
                    Stacked: \(relationship.isStacked ? "Yes" : "No")
                    Worktree: \(branch.worktreePath ?? "None")
                    """
            } catch {
                guard selectedReviewBranch == name else { return }
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
        selectedStashReference = nil
        detail = ""
        stagedPatch = nil
        unstagedPatch = nil
        guard let path, let repository = currentRepository else { return }
        let repositoryPath = selectedRepositoryPath
        let isUntracked = snapshot?.entries.first(where: { $0.path == path })?.kind == .untracked
        Task {
            do {
                let unstaged = try await (isUntracked
                    ? repository.untrackedDiff(path: path) : repository.diff(path: path))
                let staged = try await repository.diff(path: path, staged: true)
                guard selectedFile == path, selectedRepositoryPath == repositoryPath else { return }
                stagedPatch = GitPatchParser.parse(staged)
                unstagedPatch = isUntracked ? nil : GitPatchParser.parse(unstaged)
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
        selectedStashReference = nil
        detail = ""
        stagedPatch = nil
        unstagedPatch = nil
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

    func applyHunk(_ hunkID: Int, staged: Bool) {
        guard let path = selectedFile,
              let expected = (staged ? stagedPatch : unstagedPatch)?.raw else { return }
        execute { try await $0.applyHunk(
            path: path, staged: staged, hunkID: hunkID, expectedDiff: expected
        ) }
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
    func setBranchParent(_ parent: String?, for branch: String) {
        execute { try await $0.setBranchParent(parent, for: branch) }
    }
    func setBranchStacked(_ stacked: Bool, for branch: String) {
        execute { try await $0.setBranchStacked(stacked, for: branch) }
    }
    func createTag(_ name: String) { execute { try await $0.createTag(name) } }
    func deleteTag(_ name: String) { execute { try await $0.deleteTag(name) } }
    func addRemote(name: String, url: String) {
        execute { try await $0.addRemote(name: name, url: url) }
    }
    func removeRemote(_ name: String) { execute { try await $0.removeRemote(name) } }
    func saveStash() { execute { try await $0.stash() } }

    func selectStash(_ reference: String?) {
        selectedStashReference = reference
        selectedFile = nil
        selectedCommitID = nil
        selectedReviewBranch = nil
        detail = ""
        guard let reference, let repository = currentRepository else { return }
        let repositoryPath = selectedRepositoryPath
        Task {
            do {
                let diff = try await repository.stashDiff(reference)
                guard selectedStashReference == reference,
                      selectedRepositoryPath == repositoryPath else { return }
                detail = diff.isEmpty ? "This stash contains no text diff." : diff
            } catch {
                guard selectedStashReference == reference else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func applyStash(_ reference: String) {
        execute { try await $0.applyStash(reference) }
    }

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
