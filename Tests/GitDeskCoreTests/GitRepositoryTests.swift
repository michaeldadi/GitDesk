import Foundation
import GitDeskCore
import XCTest

final class GitRepositoryTests: XCTestCase {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "gitdesk-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try GitRepository.create(at: url)
        let git = GitProcess()
        _ = try git.run(in: url, ["config", "user.name", "GitDesk Tests"])
        _ = try git.run(in: url, ["config", "user.email", "gitdesk-tests@example.invalid"])
        _ = try git.run(in: url, ["config", "commit.gpgsign", "false"])
        return url
    }

    func testStatusStageCommitAndHistory() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = try GitRepository(location: url)
        let filename = "file with spaces and ; symbols.txt"
        try "hello\n".write(
            to: url.appending(path: filename), atomically: true, encoding: .utf8
        )

        let before = try await repository.snapshot()
        XCTAssertEqual(before.entries.map(\.path), [filename])
        XCTAssertEqual(before.entries.first?.kind, .untracked)

        try await repository.stage(paths: [filename])
        let staged = try await repository.snapshot()
        XCTAssertEqual(staged.entries.first?.code, "A.")

        try await repository.commit(message: "Initial commit")
        let after = try await repository.snapshot()
        XCTAssertTrue(after.entries.isEmpty)
        let history = try await repository.history()
        XCTAssertEqual(history.first?.subject, "Initial commit")
        XCTAssertNotNil(history.first?.date)
    }

    func testRenameAndUnstage() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let git = GitProcess()
        try "one\n".write(
            to: url.appending(path: "old.txt"), atomically: true, encoding: .utf8
        )
        _ = try git.run(in: url, ["add", "--", "old.txt"])
        _ = try git.run(in: url, ["commit", "-m", "Add file"])
        _ = try git.run(in: url, ["mv", "old.txt", "new.txt"])

        let repository = try GitRepository(location: url)
        let renamed = try await repository.snapshot()
        XCTAssertEqual(renamed.entries.first?.kind, .renamed)
        XCTAssertEqual(renamed.entries.first?.path, "new.txt")
        XCTAssertEqual(renamed.entries.first?.originalPath, "old.txt")

        try await repository.unstage(paths: ["new.txt", "old.txt"])
        let after = try await repository.snapshot()
        XCTAssertFalse(after.entries.isEmpty)
    }

    func testRepositoryLibrarySavesBookmark() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let database = FileManager.default.temporaryDirectory
            .appending(path: "gitdesk-library-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: database) }
        let library = try RepositoryLibrary(databaseURL: database)
        try library.add(url)
        XCTAssertEqual(try library.all().map(\.path), [url.path])
        try library.remove(path: url.path)
        XCTAssertTrue(try library.all().isEmpty)
    }

    func testWorktreeCreationAndUntrackedDiff() async throws {
        let url = try fixture()
        let sibling = url.deletingLastPathComponent()
            .appending(path: "gitdesk-worktree-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: sibling)
            try? FileManager.default.removeItem(at: url)
        }
        let git = GitProcess()
        try "base\n".write(to: url.appending(path: "base.txt"), atomically: true, encoding: .utf8)
        _ = try git.run(in: url, ["add", "--", "base.txt"])
        _ = try git.run(in: url, ["commit", "-m", "Base"])

        let repository = try GitRepository(location: url)
        try await repository.createWorktree(at: sibling, newBranch: "agent/review-one")
        let worktrees = try await repository.worktrees()
        XCTAssertEqual(worktrees.count, 2)
        XCTAssertEqual(worktrees.first(where: { $0.branch == "agent/review-one" })?.path.hasSuffix(sibling.lastPathComponent), true)

        try "new line\n".write(to: sibling.appending(path: "new.txt"), atomically: true, encoding: .utf8)
        let branchRepository = try GitRepository(location: sibling)
        let diff = try await branchRepository.untrackedDiff(path: "new.txt")
        XCTAssertTrue(diff.contains("+new line"))
    }

    func testWorktreeParserPreservesUnusualPaths() {
        let path = "/tmp/a folder\nwith newline"
        let data = Data("worktree \(path)\0HEAD abc123\0branch refs/heads/agent/topic\0\0".utf8)
        let parsed = GitWorktreeParser.parse(data)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.path, path)
        XCTAssertEqual(parsed.first?.branch, "agent/topic")
    }

    func testAppLinkRoundTripAndRejectsUnknownActions() throws {
        let path = URL(fileURLWithPath: "/tmp/a repo/branch & review", isDirectory: true)
        let link = try GitDeskLink(repository: path, view: .history)
        let parsed = try GitDeskLink.parse(link.url)
        XCTAssertEqual(parsed.repository.path, path.path)
        XCTAssertEqual(parsed.view, .history)
        XCTAssertThrowsError(try GitDeskLink.parse(URL(string: "gitdesk://push?repo=/tmp/repo&view=history")!))
    }
}
